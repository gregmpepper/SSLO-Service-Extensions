# SSL Orchestrator External Datagroup Blocking
External Datagroup Blocking is an F5 SSL Orchestrator **service extension** function for allowing users to create a custom list of URL should be blocked.   Based on the page it the blocking page shows which organization is requiring this website to be blocked.

Requires:
* BIG-IP SSL Orchestrator 17.1.x (SSLO 11.1+)

### To implement via installer:
1. Run the following from the BIG-IP shell to get the installer:
  ```bash
  curl -sk https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking-installer.sh -o external-datagroup-blocking-installer.sh
  chmod +x external-datagroup-blocking-installer.sh
  ```

2. Export the BIG-IP user:pass:
  ```bash
  export BIGUSER='admin:password'
  ```

3. Run the script to create all of the service extension objects
  ```bash
  ./external-dtagroup-blocking-installer.sh
  ```

4. The installer creates a new inspection service named "sloS_F5_External-DataGroup-Blocking". Add this inspection service to any service chain that can receive decrypted HTTP traffic. Service extension services will only trigger on decrypted HTTP, so can be inserted into service chains that may also see TLS bypass traffic (not decrypted). SSL Orchestrator will simply bypass this service for anything that is not decrypted HTTP.

------
### Customizing functionality

------
### Customizing the blocking page content

------


