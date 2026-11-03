import sys
import os
import urllib.request
import urllib.error
import http.cookiejar
import base64
import json
import subprocess

def main():
    print("[DEBUG] Python sync script started.")
    
    if len(sys.argv) < 3:
        print(f"Error: Missing arguments. Received args: {sys.argv}")
        print("Usage: python3 sync_jenkins.py <job_name> <xml_path> [delete]")
        sys.exit(1)

    job_name = sys.argv[1]
    xml_path = sys.argv[2]
    
    jenkins_url = os.environ.get("JENKINS_URL", "http://localhost:8080")
    user = "admin"
    print(f"[DEBUG] Target Jenkins URL: {jenkins_url}, Job Name: {job_name}")

    # Fetch admin password from k8s secret
    print("[DEBUG] Fetching Jenkins admin password from Kubernetes secret...")
    pass_cmd = subprocess.run(
        ["kubectl", "get", "secret", "jenkins", "-n", "jenkins", "-o", "jsonpath={.data.jenkins-admin-password}"],
        capture_output=True, text=True
    )
    
    if pass_cmd.returncode != 0:
        print(f"Error: Failed to fetch Jenkins secret from Kubernetes: {pass_cmd.stderr}")
        sys.exit(1)
        
    password = base64.b64decode(pass_cmd.stdout.strip()).decode('utf-8')
    print("[DEBUG] Successfully retrieved Jenkins admin password.")

    # Set up cookie jar for session management
    cookie_jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))
    urllib.request.install_opener(opener)

    def make_request(url, data=None, headers={}, method=None, allow_404=False):
        if method is None:
            method = "POST" if data is not None else "GET"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        auth = base64.b64encode(f"{user}:{password}".encode()).decode()
        req.add_header("Authorization", f"Basic {auth}")
        try:
            with urllib.request.urlopen(req) as response:
                return response.read()
        except urllib.error.HTTPError as e:
            if allow_404 and e.code == 404:
                return None
            print(f"HTTP Error calling {url}: {e.code} {e.reason}")
            try:
                err_body = e.read().decode('utf-8')
                print(f"Response body: {err_body}")
            except:
                pass
            sys.exit(1)
        except urllib.error.URLError as e:
            print(f"Network Error connecting to Jenkins at {url}: {e.reason}")
            sys.exit(1)

    # --- HANDLE DELETION FIRST (BEFORE READING XML) ---
    if len(sys.argv) > 3 and sys.argv[3] == "delete":
        print(f"[DEBUG] Executing delete for job: {job_name}")
        
        headers = {}
        crumb_res = make_request(f"{jenkins_url}/crumbIssuer/api/json", allow_404=True)
        if crumb_res:
            try:
                crumb_data = json.loads(crumb_res.decode())
                headers[crumb_data['crumbRequestField']] = crumb_data['crumb']
            except Exception:
                pass

        # Explicitly pass method="POST" for doDelete
        make_request(f"{jenkins_url}/job/{job_name}/doDelete", data=b"", headers=headers, method="POST", allow_404=True)
        print(f"Successfully deleted Jenkins job: {job_name}")
        sys.exit(0)
    # ---------------------------------------------------

    # Check XML file existence/content (Only for create/update)
    print(f"[DEBUG] Reading XML configuration file from: {xml_path}")
    try:
        with open(xml_path, "r") as f:
            config_xml = f.read()
        print(f"[DEBUG] Successfully read XML file ({len(config_xml)} bytes).")
    except Exception as e:
        print(f"Error reading XML file at {xml_path}: {e}")
        sys.exit(1)

    # Get crumb token for CSRF protection
    print("[DEBUG] Requesting CSRF crumb issuer...")
    headers = {'Content-Type': 'application/xml'}
    crumb_res = make_request(f"{jenkins_url}/crumbIssuer/api/json", allow_404=True)
    if crumb_res:
        try:
            crumb_data = json.loads(crumb_res.decode())
            headers[crumb_data['crumbRequestField']] = crumb_data['crumb']
            print(f"[DEBUG] Acquired CSRF crumb header: {crumb_data['crumbRequestField']}")
        except Exception as e:
            print(f"[DEBUG] Warning: Failed to parse crumb JSON: {e}")
    else:
        print("[DEBUG] Notice: Crumb issuer not found or disabled.")

    # Check if job exists
    print(f"[DEBUG] Checking if job '{job_name}' already exists in Jenkins...")
    job_exists = make_request(f"{jenkins_url}/job/{job_name}/api/json", allow_404=True)
    
    if job_exists is not None:
        print(f"[DEBUG] Job exists. Updating configuration...")
        make_request(f"{jenkins_url}/job/{job_name}/config.xml", data=config_xml.encode('utf-8'), headers=headers, method="POST")
        print(f"Successfully updated Jenkins job: {job_name}")
    else:
        print(f"[DEBUG] Job does not exist. Creating new item...")
        make_request(f"{jenkins_url}/createItem?name={job_name}", data=config_xml.encode('utf-8'), headers=headers, method="POST")
        print(f"Successfully created Jenkins job: {job_name}")

if __name__ == "__main__":
    main()