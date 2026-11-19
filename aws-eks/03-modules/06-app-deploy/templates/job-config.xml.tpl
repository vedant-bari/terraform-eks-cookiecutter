<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Managed via Terraform Blueprint &amp; Terragrunt</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent {
        label 'docker-agent'
    }

    environment {
        IMAGE_REPO_NAME     = "${image_repo}"
        ECR_REGISTRY        = "${ecr_registry}"
        GITHUB_CREDENTIAL   = "${github_credentials}"

        AWS_REGION          = "${aws_region}"
        CLUSTER_NAME        = "${cluster_name}"
        K8S_NAMESPACE       = "${k8s_namespace}"
        DEPLOYMENT_NAME     = "${deployment_name}"
        CONTAINER_NAME      = "${container_name}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Fetching code from GitHub repository'
                git branch: '${branch}',
                    credentialsId: "$${env.GITHUB_CREDENTIAL}",
                    url: '${git_url}'
            }
        }

        stage('Build and Push to ECR') {
            steps {
                script {
                    sh 'git config --global --add safe.directory $(pwd)'
                    def dockerTag = sh(label: '', returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    env.DOCKER_TAG = dockerTag

                    // 1. Fetch an ECR login token with the agent's Pod Identity role.
                    //    It is passed through a workspace file (shared by all containers)
                    //    so it never appears in a command line or the build log.
                    container('aws') {
                        sh 'aws ecr get-login-password --region "$AWS_REGION" > .ecr-login'
                    }

                    // 2. Build and push the image using the docker container
                    container('docker') {
                        sh "docker build . -t $${env.IMAGE_REPO_NAME}:$${env.DOCKER_TAG}"
                        sh "docker tag $${env.IMAGE_REPO_NAME}:$${env.DOCKER_TAG} $${env.IMAGE_REPO_NAME}:latest"

                        // Piped with cat: an input redirect would be invalid inside this XML element.
                        sh 'cat .ecr-login | docker login --username AWS --password-stdin "$ECR_REGISTRY"; rc=$?; rm -f .ecr-login; exit $rc'

                        sh "docker push $${env.IMAGE_REPO_NAME}:$${env.DOCKER_TAG}"
                        sh "docker push $${env.IMAGE_REPO_NAME}:latest"
                    }
                }
            }
        }

        stage('EKS Deploy') {
            steps {
                container('aws') {
                    script {
                        // kubectl uses the agent pod's service account (jenkins-agent RBAC).
                        sh "kubectl set image deployment/$${env.DEPLOYMENT_NAME} $${env.CONTAINER_NAME}=$${env.IMAGE_REPO_NAME}:$${env.DOCKER_TAG} -n $${env.K8S_NAMESPACE}"
                    }
                }
            }
        }

        stage('Verify Rollout') {
            steps {
                container('aws') {
                    script {
                        sh "kubectl rollout status deployment/$${env.DEPLOYMENT_NAME} --timeout=300s -n $${env.K8S_NAMESPACE}"
                    }
                }
            }
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
