#!/bin/bash

read -p "Do you already install velero in this cluster with the correct bucket (y/n) : " veleroinstalled

if [[ ${veleroinstalled} == "y" ]]
then
    read -p "Enter bucket name from where you want to take backup : " backupbucket
    echo "Checking bucket name................"
    backupbucketname=`velero get backup-location | awk '{print $3}' | tail -n +2`
    if [[ ${backupbucket} == "$backupbucketname" ]]
    then 
        velero restore create all-crds-restore --from-backup all-crds-backup 
        velero restore create scheduledworkflows-kubeflow-org-restore --from-backup scheduledworkflows-kubeflow-org-backup
        velero restore create workflows-argoproj-io-restore --from-backup workflows-argoproj-io-backup
        velero restore create cronworkflows-argoproj-io-restore --from-backup cronworkflows-argoproj-io-backup
        velero restore create viewers-kubeflow-org-restore --from-backup viewers-kubeflow-org-backup
        velero restore create all-priorityclass-restore --from-backup all-priorityclass-backup
        velero restore create all-storageclass-restore --from-backup all-storageclass-backup
        velero restore create dlf-ns-restore --from-backup dlf-ns-backup
        velero restore create istio-system-ns-restore --from-backup istio-system-ns-backup
        velero restore create default-ns-restore --from-backup default-ns-backup
        velero restore create keycloak-ns-restore --from-backup keycloak-ns-backup
        velero restore create kubeflow-ns-restore --from-backup kubeflow-ns-backup
        velero restore create application-ns-restore --from-backup application-ns-backup
        velero restore create mlflow-ns-restore --from-backup mlflow-ns-backup
        velero restore create models-ns-restore --from-backup models-ns-backup
        velero restore create monitoring-ns-restore --from-backup monitoring-ns-backup
        
        #------------------------------

        sudo velero get backup | awk '{print $1}' | tail -n +2 > /root/velero-backup-ns-list.txt 
        sudo sed -i '/all-crds-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/scheduledworkflows-kubeflow-org-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/workflows-argoproj-io-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/cronworkflows-argoproj-io-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/viewers-kubeflow-org-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/all-priorityclass-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/all-storageclass-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/dlf-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/istio-system-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/default-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/keycloak-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/kubeflow-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/application-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/mlflow-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/models-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/monitoring-ns-backup/d' /root/velero-backup-ns-list.txt

        #---------------------------------

        file=/root/velero-backup-ns-list.txt
        for i in `cat $file`
        do
            velero restore create "$i"-restore --from-backup $i
        done
    else
        echo "Please enter correct bucket name. If bucket is different then delete the velero namespace. Before deleting velero namespace remove the finalizer of the velero namespace."
    fi
elif [[ ${veleroinstalled} == "n" ]]
then

    velero_image="velero/velero:v1.7.1"

    read -p "Do you want to restore the Katonic platform cluster [y/n] : " restore

    read -p "Select cloud provider where you take the backup(AWS/Azure/GCP) : " cloudprovider

    read -p "Enter Bucket name : " bucket

    read -p "Enter velero.yml file path : " velero_file_path

    if [[ ${restore} == "y"  ]]
    then

        wget -o /tmp/velero.tar.gz https://github.com/vmware-tanzu/velero/releases/download/v1.7.1/velero-v1.7.1-linux-amd64.tar.gz

        tar -xf velero-v1.7.1-linux-amd64.tar.gz 

        cp velero-v1.7.1-linux-amd64/velero /usr/local/bin/velero

        chmod +x /usr/local/bin/velero

        if [[ ${cloudprovider} == "AWS"  ]]
        then
            read -p "Enter AWS credential path to access the bucket :" aws_credentials_path
            read -p "Enter backup bucket region : " s3_bucket_region        

            velero install --provider aws --plugins velero/velero-plugin-for-aws:v1.0.0 --bucket $bucket --secret-file=$aws_credentials_path --use-volume-snapshots=false --backup-location-config region=$s3_bucket_region,s3ForcePathStyle="true" --image=$velero_image  --use-restic

        elif [[ ${cloudprovider} == "Azure"  ]]
        then
            
            read -p "Enter resource group name of bucket where you take backup of cluster :" $resource_group_name
            read -p "Enter Azure Subscription ID : " $azure_subscription_id
            read -p "Azure storage account id of backup bucket(blob container) : " $AZURE_STORAGE_ACCOUNT_ID
            
            AZURE_STORAGE_ACCOUNT_ACCESS_KEY=`az storage account keys list --account-name $AZURE_STORAGE_ACCOUNT_ID --query "[?keyName == 'key1'].value" -o tsv`
            echo "AZURE_STORAGE_ACCOUNT_ACCESS_KEY=$AZURE_STORAGE_ACCOUNT_ACCESS_KEY" > /root/credentials-velero
            echo "AZURE_CLOUD_NAME=AzurePublicCloud" >> /root/credentials-velero

            velero install --provider azure --plugins velero/velero-plugin-for-microsoft-azure:v1.4.0 --image=$velero_image --bucket=$bucket --secret-file /root/credentials-velero --backup-location-config resourceGroup=$resource_group_name,storageAccount=$AZURE_STORAGE_ACCOUNT_ID,storageAccountKeyEnvVar=AZURE_STORAGE_ACCOUNT_ACCESS_KEY,subscriptionId=$azure_subscription_id --use-volume-snapshots=false --use-restic

        elif [[ ${cloudprovider} == "GCP"  ]]
        then
            
            read -p "Enter the katonic-{random_value} bucket service_account id(email) : " $service_account_email

            gcloud iam service-accounts keys create credentials-velero --iam-account $service_account_email

            velero install --provider gcp --plugins velero/velero-plugin-for-gcp:v1.5.0 --bucket $bucket --secret-file ./credentials-velero

        else
            echo "Please enter correct value AWS, Azure or GCP"
        fi

        kubectl apply -f $velero_file_path

        sleep 1m

        velero restore create all-crds-restore --from-backup all-crds-backup 
        velero restore create scheduledworkflows-kubeflow-org-restore --from-backup scheduledworkflows-kubeflow-org-backup
        velero restore create workflows-argoproj-io-restore --from-backup workflows-argoproj-io-backup
        velero restore create cronworkflows-argoproj-io-restore --from-backup cronworkflows-argoproj-io-backup
        velero restore create viewers-kubeflow-org-restore --from-backup viewers-kubeflow-org-backup
        velero restore create all-priorityclass-restore --from-backup all-priorityclass-backup
        velero restore create all-storageclass-restore --from-backup all-storageclass-backup
        velero restore create dlf-ns-restore --from-backup dlf-ns-backup
        velero restore create istio-system-ns-restore --from-backup istio-system-ns-backup
        velero restore create default-ns-restore --from-backup default-ns-backup
        velero restore create keycloak-ns-restore --from-backup keycloak-ns-backup
        velero restore create kubeflow-ns-restore --from-backup kubeflow-ns-backup
        velero restore create application-ns-restore --from-backup application-ns-backup
        velero restore create mlflow-ns-restore --from-backup mlflow-ns-backup
        velero restore create models-ns-restore --from-backup models-ns-backup
        velero restore create monitoring-ns-restore --from-backup monitoring-ns-backup
        
        #------------------------------

        sudo velero get backup | awk '{print $1}' | tail -n +2 > /root/velero-backup-ns-list.txt 
        sudo sed -i '/all-crds-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/scheduledworkflows-kubeflow-org-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/workflows-argoproj-io-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/cronworkflows-argoproj-io-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/viewers-kubeflow-org-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/all-priorityclass-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/all-storageclass-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/dlf-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/istio-system-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/default-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/keycloak-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/kubeflow-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/application-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/mlflow-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/models-ns-backup/d' /root/velero-backup-ns-list.txt
        sudo sed -i '/monitoring-ns-backup/d' /root/velero-backup-ns-list.txt

        #---------------------------------

        file=/root/velero-backup-ns-list.txt
        for i in `cat $file`
        do
            velero restore create "$i"-restore --from-backup $i
        done

    elif [[ ${restore} == "n"  ]]
    then
            echo "Restoration cancel."
    else
            echo "Please enter y or n"
    fi
else
    echo "Please enter y/n !!"
fi