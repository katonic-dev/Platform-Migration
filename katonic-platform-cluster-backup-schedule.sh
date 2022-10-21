#!/bin/bash

velero_image="velero/velero:v1.7.1"

read -p "Do you want to restore the Katonic platform cluster [y/n] : " restore
read -p "Select cloud provider where you take the backup(AWS/Azure/GCP) : " cloudprovider
read -p "Enter Bucket name : " bucket
read -p "Enter velero.yml file path : " velero_file_path
read -p "Backup schedule time/date:" backup_schedule
read -p "Backup expiration time/date:" backup_expiration

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

    velero create schedule scheduledworkflows-kubeflow-org-backup --include-resources scheduledworkflows.kubeflow.org --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule workflows-argoproj-io-backup --include-resources workflows.argoproj.io --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule cronworkflows-argoproj-io-backup --include-resources cronworkflows.argoproj.io --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule viewers-kubeflow-org-backup --include-resources viewers.kubeflow.org --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule all-crds-backup --include-resources customresourcedefinitions.apiextensions.k8s.io --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule all-storageclass-backup --include-resources storageclasses.storage.k8s.io --schedule=$backup_schedule --ttl $backup_expiration
    velero create schedule all-priorityclass-backup --include-resources priorityclasses.scheduling.k8s.io --schedule=$backup_schedule --ttl $backup_expiration

    sudo kubectl get ns | awk '{print $1}' | tail -n +2 > /root/ns-list.txt 

    sudo sed -i '/velero/d' /root/ns-list.txt
    sudo sed -i '/kube-node-lease/d' /root/ns-list.txt 
    sudo sed -i '/kube-public/d' /root/ns-list.txt 
    sudo sed -i '/kube-system/d' /root/ns-list.txt

    file=/root/ns-list.txt
    for i in `cat $file`
    do
        velero create schedule "$i"-ns-backup --include-namespaces $i --schedule=$backup_schedule --ttl $backup_expiration
    done

elif [[ ${restore} == "n"  ]]
then
    echo "Backup process cancel."
else
    echo "Please enter y or n"
fi