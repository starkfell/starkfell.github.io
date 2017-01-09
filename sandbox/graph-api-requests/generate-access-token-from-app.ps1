
# Application Client ID and Client Secret
$Client_ID      = "5dc13166-0814-45ad-a670-2207eed8910c"
$Client_Secret  = "fAd0ZF2eiX0+nWagwZLCKvXjAzIK3L35sB5/Nic744E="

# Encoding the Client ID and Client Secret.
$Client_ID_Encoded     = [System.Web.HttpUtility]::UrlEncode($Client_ID)
$Client_Secret_Encoded = [System.Web.HttpUtility]::UrlEncode($Client_Secret)

# Creating the Request included in the Body.
$Body = "grant_type=client_credentials&client_id=$Client_ID_Encoded&client_secret=$Client_Secret_Encoded&resource=https://graph.microsoft.com"

# Defining the Content Type.
$ContentType = "application/x-www-form-urlencoded"

# Generating the Bearer Token for the Application.
$Token_Request = Invoke-RestMethod `
    -Uri https://login.microsoftonline.com/7f24e4c5-12f1-4047-afa1-c15d6927e745/oauth2/token `
    -Body $Body `
    -ContentType $ContentType `
    -Method Post

$Token_Request

$Access_Token = $Token_Request.access_token

Write-Output "|$Access_Token|"

Write-Output "|$Access_Token|" | Out-File "C:\Windows\Temp\token.txt" -Force

exit 0


# --- CONTENT BELOW HERE IS FOR CREATING INVITATIONS USING MICROSOFT GRAPH --- 
#Which currently doesn't support Microsoft Accounts and only works with Azure AD Accounts.


# Defining the Invitation to include in the Body of the Request.
$Invitation = @{
  invitedUserEmailAddress = "ryan.irujo@lumagate.com"
  inviteRedirectUrl = "http://graph-api-sandbox/"
}

# Converting the Invitation Request to JSON to included in the Body.
$Invitation_JSON = $Invitation | ConvertTo-Json

# Defining the Content Type for the Invitation. 
$Invitation_Content_Type = "application/json"


# Creating the Invitation for the Application.
Invoke-RestMethod `
-Uri https://graph.microsoft.com/beta/invitations `
-Body $Invitation_JSON `
-ContentType $Invitation_Content_Type `
-Method Post `
-Headers @{ "Authorization" = "Bearer $Access_Token" }
