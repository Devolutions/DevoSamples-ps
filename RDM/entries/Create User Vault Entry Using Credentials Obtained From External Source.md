# Create a User Vault entry using Credentials obtained from an external source 

##### This is a guide to create a PowerShell type Entry with an embedded script to Create a User Vault entry using Credentials obtained from an external source.

### Let's start by creating the PowerShell Entry. 

##### 1. Start Remote Desktop Manager <br />

##### 2. Click on the New Entry Icon

![](images/NewEntryButton.jpg)

##### 3. Select PowerShell (Session)

![](images/EntryType.jpg)

##### 4. A few things will need to be configured session specific which we will go over: <br />

![](images/PSSession.jpg)


* Name is a fairly simple one, go ahead a chose one now.

* For Credentials, this is particular as it will be used to authenticate your external source later. In our case, we have a credentials within the Vault that we pointing our session to.  

* We will set the session to use Embedded Script. I will go over what to put in there later in this document. 

* Arguments are where will will "call" information from the session. In this case we are calling `"$USERNAME$" "$PASSWORD$" "$CUSTOM_FIELD1$"`. 

* Very import to Activate and Set "Load RDM Module CmdLet" to Module, if not nothing will get created within RDM. 
   

> :information_source: For our Arguments.`"$USERNAME$" "$PASSWORD$" "$CUSTOM_FIELD1$"`<br/><br/> 
![](images/CustomFields.jpg)<br/><br/>
-If you noticed above we used `"$CUSTOM_FIELD1$"`. <br/>
-By setting this argument we can now call this in our script as you would a variable. <br/>
-We set this on our session's properties, under Custom Fields. <br/>
-You can rename the field by clicking the hyperlink, which in our case we named ***"HPA Entry Name"*** and its value is ***"HPA Switch"***.

> :warning: To use Password 
in these arguments you need to make sure on **BOTH** the Credential Entry and PowerShell Session that ***"Allow Password in variable"*** is enabled, as shown below.<br/><br/>
![](images/PasswordVariables.jpg)<br/><br/>
:warning: **As well as on Administration > System Settings > Password Policy "Allow password variables for all entries."** <br/><br/>
![](images/SystemSetting.jpg)

   

### PowerShell Script    
    
> :information_source: *Please note we used test values to simulate getting credentials from an external source.* 
<br /><br />
:warning: If you are copy/pasting please paste using "CTRL + ALT + V" then select Unformatted Text or you will receive errors.


```powershell
#Use Credentials sent by RDM to connect to external System
$Username = "$USERNAME$"
$Password = "$PASSWORD$"
  
#LOAD High Privlege account 
  
#Here we used test values 
$HPAUser = "TestUser"
$HPAPass = ConvertTo-SecureString "Passw0rd!" -AsPlainText -Force
#Obtained HPA Credential conversion to PSCredential
$HPAAccount = New-Object System.Management.Automation.PSCredential($HPAUser,$HPAPass)
if (Get-RDMPrivateSession -Name "$CUSTOM_FIELD1$" -ErrorAction:SilentlyContinue) {$doesExist= $true} else {$doesExist= $false}
if(!($doesExist)){
    $entry = New-RDMSession -Name "$CUSTOM_FIELD1$" -Type Credential
    Set-RDMSessionUsername $entry -UserName $HPAAccount.UserName
    Set-RDMSessionPassword $entry -Password $HPAAccount.Password
    Set-RDMPrivateSession $entry -Refresh
    Write-Output "Session created in your User Vault."
}else {
    $entry = Get-RDMPrivateSession -Name "$CUSTOM_FIELD1$"
    Set-RDMSessionUsername $entry -Username $HPAAccount.Username
    Set-RDMSessionPassword $entry -Password $HPAAccount.Password
    Set-RDMPrivateSession $entry -Refresh
    Write-Output "Session updated in your User Vault."
}
```

