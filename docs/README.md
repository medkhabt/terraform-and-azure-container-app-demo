I am documenting in this file all the actions that i had to do manually.


## Microsoft.OperationalInsights provider 
I had to register Microsoft.OperationalInsights provider to my subscription. THis is required 
for the Log Analytics. `az provider register --namespace Microsoft.OperationalInsights`
And to check if it was registered
```bash
az provider show \
  --namespace Microsoft.OperationalInsights \
  --query registrationState \
  -o tsv
```

I had to the the same for Microsoft.App provider, which is required for the provisionning of the azure container
app environment `az provider register --namespace Microsoft.App`



## TODOs
can i work with private vlan and check with the configuration.
