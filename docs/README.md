I am documenting in this file all the actions that i had to do manually.


## Azure providers
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


## HCP Terraform integration
### create a workspace 
A workspace represents :
    - the terraform configuration
    - a single state file
    - variables values

one of the workflows of the workspace is the `VCS-driven workflow`. HCP Terraform fetches the
configuration from the version control repo and automatically starts plan and apply operations 
whenever we make changes to the repo. ( so repo is the single source of truth of the workspace ).


I had to go to app.terraform.io and create an account also create a workspace. First i wanted to use vcs 
driven workflow, but for the demo, it needed to many changes, and i am not sure if it's even the right 
thing to do, so i switched the workspace to local execution, i run terraform init and plan and confirmed that
i wanted to migrate the state from my laptop to the terraofrm repo.
