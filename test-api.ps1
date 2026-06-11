# BotBazaar API Test Script
# This script tests all major endpoints of your deployed bot

# Configuration
$BASE_URL = "https://botbazaar-production.up.railway.app"
$TEST_EMAIL = "test-$(Get-Random)@example.com"
$TEST_PASSWORD = "Test1234!@"
$TEST_NAME = "Test User $(Get-Date -Format 'HHmmss')"

# Color output
function Write-Success { Write-Host "[PASS] $args" -ForegroundColor Green }
function Write-ErrorMsg { Write-Host "[FAIL] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Section { Write-Host "`n==================================================" -ForegroundColor Yellow; Write-Host $args -ForegroundColor Yellow; Write-Host "==================================================`n" -ForegroundColor Yellow }

# Test counter
$tests = @{Passed = 0; Failed = 0; Total = 0}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )
    
    $tests.Total++
    Write-Info "Testing: $Name"
    Write-Info "  $Method $Uri"
    
    try {
        $params = @{
            Method = $Method
            Uri = $Uri
            Headers = $Headers
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = $Body | ConvertTo-Json
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-RestMethod @params
        Write-Success "$Name - Status: OK"
        $tests.Passed++
        return $response
    }
    catch {
        Write-ErrorMsg "$Name - Error: $($_.Exception.Message)"
        $tests.Failed++
        return $null
    }
}

# Start tests
Write-Section "BotBazaar API Testing Suite"
Write-Info "Base URL: $BASE_URL"
Write-Info "Test Email: $TEST_EMAIL"
Write-Info "Starting tests at $(Get-Date)"

# Test 1: Health Check
Write-Section "1. Health Check"
$health = Test-Endpoint -Name "Health Check" -Method "GET" -Uri "$BASE_URL/health"
if ($health) {
    Write-Info "Status: $($health.status)"
    Write-Info "Environment: $($health.environment)"
}

# Test 2: Register User
Write-Section "2. User Registration"
$registerBody = @{
    email = $TEST_EMAIL
    password = $TEST_PASSWORD
    first_name = "Test"
    last_name = "User"
    phone = "+919876543210"
}
$registerResponse = Test-Endpoint -Name "Register User" -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $registerBody
$userId = $registerResponse.id
$accessToken = $registerResponse.accessToken
$refreshToken = $registerResponse.refreshToken

if ($registerResponse) {
    Write-Info "User ID: $userId"
    Write-Info "Access Token: $($accessToken.Substring(0, 20))..."
}

# Test 3: Login
Write-Section "3. User Login"
$loginBody = @{
    email = $TEST_EMAIL
    password = $TEST_PASSWORD
}
$loginResponse = Test-Endpoint -Name "Login User" -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $loginBody
if ($loginResponse) {
    $accessToken = $loginResponse.accessToken
    Write-Info "Token obtained: $($accessToken.Substring(0, 20))..."
}

# Test 4: Get User Profile
Write-Section "4. Get User Profile"
$headers = @{
    "Authorization" = "Bearer $accessToken"
}
$profileResponse = Test-Endpoint -Name "Get Profile" -Method "GET" -Uri "$BASE_URL/api/auth/me" -Headers $headers
if ($profileResponse) {
    Write-Info "Email: $($profileResponse.email)"
    Write-Info "Name: $($profileResponse.first_name) $($profileResponse.last_name)"
}

# Test 5: Update Profile
Write-Section "5. Update User Profile"
$updateBody = @{
    first_name = "Updated"
    last_name = "Name"
}
$updateResponse = Test-Endpoint -Name "Update Profile" -Method "PUT" -Uri "$BASE_URL/api/auth/me" -Headers $headers -Body $updateBody

# Test 6: Get Subscriptions
Write-Section "6. Get Subscriptions"
$subscriptionsResponse = Test-Endpoint -Name "Get Subscriptions" -Method "GET" -Uri "$BASE_URL/api/subscriptions" -Headers $headers
if ($subscriptionsResponse) {
    Write-Info "Subscriptions count: $($subscriptionsResponse.data.Count)"
}

# Test 7: Get Bot Templates
Write-Section "7. Get Bot Templates"
$templatesResponse = Test-Endpoint -Name "Get Templates" -Method "GET" -Uri "$BASE_URL/api/templates" -Headers $headers
if ($templatesResponse) {
    Write-Info "Templates count: $($templatesResponse.Count)"
}

# Test 8: Get Available Plans
Write-Section "8. Get Payment Plans"
$plansResponse = Test-Endpoint -Name "Get Plans" -Method "GET" -Uri "$BASE_URL/api/payments/plans" -Headers $headers
if ($plansResponse) {
    Write-Info "Plans available: $($plansResponse.Count)"
}

# Test 9: Refresh Token
Write-Section "9. Refresh Access Token"
$refreshBody = @{
    refreshToken = $refreshToken
}
$refreshResponse = Test-Endpoint -Name "Refresh Token" -Method "POST" -Uri "$BASE_URL/api/auth/refresh" -Body $refreshBody
if ($refreshResponse) {
    $newAccessToken = $refreshResponse.accessToken
    Write-Info "New token obtained: $($newAccessToken.Substring(0, 20))..."
}

# Test 10: Change Password
Write-Section "10. Change Password"
$changePasswordBody = @{
    currentPassword = $TEST_PASSWORD
    newPassword = "NewTest1234!@"
}
$changePasswordResponse = Test-Endpoint -Name "Change Password" -Method "POST" -Uri "$BASE_URL/api/auth/change-password" -Headers $headers -Body $changePasswordBody

# Test 11: Get Invoices
Write-Section "11. Get Invoices"
$invoicesResponse = Test-Endpoint -Name "Get Invoices" -Method "GET" -Uri "$BASE_URL/api/invoices" -Headers $headers
if ($invoicesResponse) {
    Write-Info "Invoices count: $($invoicesResponse.data.Count)"
}

# Test 12: 404 Error Handling
Write-Section "12. Error Handling (404 Test)"
$notFoundResponse = Test-Endpoint -Name "Non-existent Endpoint" -Method "GET" -Uri "$BASE_URL/api/nonexistent" -Headers $headers

# Final Summary
Write-Section "Test Summary"
Write-Host "Total Tests: $($tests.Total)" -ForegroundColor Cyan
Write-Success "Passed: $($tests.Passed)"
if ($tests.Failed -gt 0) {
    Write-ErrorMsg "Failed: $($tests.Failed)"
} else {
    Write-Success "Failed: $($tests.Failed)"
}
$passPercentage = [math]::Round(($tests.Passed / $tests.Total) * 100, 2)
Write-Info "Success Rate: $passPercentage%"
Write-Info "Completed at $(Get-Date)"

if ($tests.Failed -eq 0) {
    Write-Host "`n*** ALL TESTS PASSED! Your BotBazaar API is working perfectly! ***`n" -ForegroundColor Green -BackgroundColor Black
} else {
    Write-Host "`n*** Some tests failed. Please review the errors above. ***`n" -ForegroundColor Yellow -BackgroundColor Black
}
