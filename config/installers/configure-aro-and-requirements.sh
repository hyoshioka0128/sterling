#Required Software Pacakges
sudo dnf -y install jq

#Azure CLI Install
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo
sudo dnf -y install azure-cli 

#Azure CLI Login
az login --service-principal -u $(cat ~/.azure/osServicePrincipal.json | jq -r .clientId) -p $(cat ~/.azure/osServicePrincipal.json | jq -r .clientSecret) --tenant $(cat ~/.azure/osServicePrincipal.json | jq -r .tenantId) --output none && az account set -s $(cat ~/.azure/osServicePrincipal.json | jq -r .subscriptionId) --output none

#Openshift CLI Install
mkdir /tmp/OCPInstall
wget -nv "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz" -O /tmp/OCPInstall/openshift-client-linux.tar.gz
tar xvf /tmp/OCPInstall/openshift-client-linux.tar.gz -C /tmp/OCPInstall
sudo cp /tmp/OCPInstall/oc /usr/bin

#Helm install
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

#OC Login
apiServer=$(az aro show -g $(cat ~/.azure/osServicePrincipal.json | jq -r .resourceGroup) -n $ARO_CLUSTER_NAME --query apiserverProfile.url -o tsv | sed -e 's#^https://##; s#/##' )
adminpassword=az aro list-credentials --name $ARO_CLUSTER_NAME --resource-group $(cat ~/.azure/osServicePrincipal.json | jq -r .resourceGroup) -query kubeadminPassword -o tsv
oc login $apiServer -u kubeadmin -p $adminpassword

#Install & Configure Azure Files CSI Drivers and Storage Classes
wget -nv https://raw.githubusercontent.com/Azure/sterling/$branchName/config/azure-file-storage/configure-azurefiles-driver.sh -O /tmp/configure-azurefiles-driver.sh
chmod u+x /tmp/configure-azurefiles-driver.sh
/tmp/configure-azurefiles-driver.sh

#Configure IBM Operator Catalog
oc create namespace openshift-marketplace
wget -nv https://raw.githubusercontent.com/Azure/sterling/$branchName/config/operators/ibm-integration-operatorgroup.yaml -O /tmp/ibm-integration-operatorgroup.yaml
oc apply -f /tmp/ibm-integration-operatorgroup.yaml

#Install OMS Opeartor
if [ "$WHICH_OMS" == "1" ] 
then
  export OMS_VERSION="icr.io/cpopen/ibm-oms-pro-case-catalog:v1.0"
elif [ "$WHICH_OMS" == "2" ]
then
  export OMS_VERSION="icr.io/cpopen/ibm-oms-ent-case-catalog:v1.0"
fi
wget -nv https://raw.githubusercontent.com/Azure/sterling/$branchName/config/operators/install-oms-operator.yaml -O /tmp/install-oms-operator.yaml
envsubst < /tmp/install-oms-operator.yaml > /tmp/install-oms-operator.yaml
oc apply -f /tmp/install-oms-operator.yaml

#Optional Install Portion
if [ "$INSTALL_DB2_CONTAINER" == "Y" ] || [ "$INSTALL_DB2_CONTAINER" == "y" ]
then
  echo "Installing DB2 Container in namespace ${omsNamespace}..."
fi
if [ "$INSTALL_MQ_CONTAINER" == "Y" ] || [ "$INSTALL_MQ_CONTAINER" == "y" ]
then
  echo "Installing MQ Container in namespace ${omsNamespace}..."
fi    