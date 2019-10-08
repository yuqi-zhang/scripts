#!/bin/bash

AZ_DISK_ID=fio_test_disk_3
AZ_RESOURCE_GROUP=os4-common
AZ_SIZE_GB=2048
AZ_SKU=Premium_LRS
AZ_VM_NAME=jerzhang-uswest-test-2
AZ_CACHING=ReadOnly

AZ_SSH_KEY=~/.ssh/libra.pem
AZ_SSH_ID=core@40.78.23.38

cleanup() {
    az vm disk detach -g $AZ_RESOURCE_GROUP --vm-name $AZ_VM_NAME --name $AZ_DISK_ID
    az disk delete --name $AZ_DISK_ID --resource-group $AZ_RESOURCE_GROUP --yes
}

for i in {1..25}
do
    echo "This is run number ${i}"
    az vm disk attach \
        --name $AZ_DISK_ID \
        --new \
        --resource-group $AZ_RESOURCE_GROUP \
        --size-gb $AZ_SIZE_GB \
        --sku $AZ_SKU \
        --vm-name $AZ_VM_NAME \
        --caching $AZ_CACHING

    ssh -i ${AZ_SSH_KEY} ${AZ_SSH_ID} << EOF
rm -rf fio.out
echo "Running FIO test..."
sudo fio --filename=/dev/sdc --name=benchmark --ioengine=sync --rw=write --bs=2k --numjobs=1 --time_based --runtime=30 --group_reporting --direct=1 --fdatasync=1 --size=22m > fio.out
echo "Test complete."
SYNC_PERCENTILES=\$(cat fio.out | grep -A4 "sync percentiles" | grep 99.00| grep -oP '(?<=\[).+?(?=\])')
P99_FSYNC=\$(echo \$SYNC_PERCENTILES| awk '{print \$1;}')
echo "This run's P99 FSYNC is: \$P99_FSYNC"
if [ \$P99_FSYNC -gt 50 ]
then
    echo "BAD DISK: Latency at \$P99_FSYNC"
fi
EOF

    cleanup
    echo "Sleeping 15s to allow the disk to be reclaimed"
    sleep 15s
done

cleanup
