# FAZA 3: Backend - Real-time provjera dostupnosti i checkout sigurnost
# PowerShell skripta za automatsko testiranje

$baseUrl = "http://localhost:5169/api"
$results = @()

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message,
        [object]$Response = $null
    )
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Message = $Message
        Response = $Response
        Timestamp = Get-Date
    }
    
    $results += $result
    
    $color = if ($Passed) { "Green" } else { "Red" }
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "  → $Message" -ForegroundColor Gray
    }
}

function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Endpoint,
        [string]$Token = "",
        [object]$Body = $null
    )
    
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }
    
    $uri = "$baseUrl$Endpoint"
    
    try {
        if ($Body) {
            $bodyJson = $Body | ConvertTo-Json -Depth 10
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $bodyJson -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -ErrorAction Stop
        }
        return @{ Success = $true; Data = $response }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        return @{ Success = $false; StatusCode = $statusCode; Error = $errorBody; Exception = $_.Exception.Message }
    }
}

Write-Host "`n=== FAZA 3: Backend Checkout Security Tests ===" -ForegroundColor Cyan
Write-Host "Base URL: $baseUrl`n" -ForegroundColor Gray

# Test Setup: Login
Write-Host "`n[SETUP] Logging in as user@sapplauz.ba..." -ForegroundColor Yellow
$loginBody = @{
    email = "user@sapplauz.ba"
    password = "User123!"
} | ConvertTo-Json

$loginResponse = Invoke-ApiRequest -Method "POST" -Endpoint "/auth/login" -Body $loginBody

if (-not $loginResponse.Success) {
    Write-Host "❌ Failed to login. Please ensure API is running and user exists." -ForegroundColor Red
    exit 1
}

$token = $loginResponse.Data.token
Write-Host "✅ Login successful. Token obtained." -ForegroundColor Green

# Test 1: Get Performances to find available performance
Write-Host "`n[SETUP] Getting available performances..." -ForegroundColor Yellow
$performancesResponse = Invoke-ApiRequest -Method "GET" -Endpoint "/performances" -Token $token

if (-not $performancesResponse.Success) {
    Write-TestResult -TestName "Get Performances" -Passed $false -Message "Failed to get performances: $($performancesResponse.Exception)"
    exit 1
}

$performances = $performancesResponse.Data
if ($performances.Count -eq 0) {
    Write-Host "⚠️  No performances found. Please create a performance first." -ForegroundColor Yellow
    exit 1
}

$testPerformance = $performances | Where-Object { $_.availableSeats -gt 0 } | Select-Object -First 1
if (-not $testPerformance) {
    Write-Host "⚠️  No performances with available seats found." -ForegroundColor Yellow
    exit 1
}

$performanceId = $testPerformance.id
$institutionId = $testPerformance.show.institutionId
$availableSeats = $testPerformance.availableSeats

Write-Host "✅ Found performance ID: $performanceId with $availableSeats available seats" -ForegroundColor Green

# TEST 1: Quantity Validation - Too many tickets
Write-Host "`n[TEST 1] Quantity Validation - Too many tickets..." -ForegroundColor Cyan
$test1Body = @{
    institutionId = $institutionId
    orderItems = @(
        @{
            performanceId = $performanceId
            quantity = 10000  # Way more than available
        }
    )
} | ConvertTo-Json

$test1Response = Invoke-ApiRequest -Method "POST" -Endpoint "/orders" -Token $token -Body ($test1Body | ConvertFrom-Json)

if (-not $test1Response.Success -and $test1Response.StatusCode -eq 400) {
    $errorMsg = $test1Response.Error.message
    if ($errorMsg -like "*Neko je bio brži*" -or $errorMsg -like "*preostalo samo*") {
        Write-TestResult -TestName "TEST 1: Quantity Validation" -Passed $true -Message $errorMsg
    } else {
        Write-TestResult -TestName "TEST 1: Quantity Validation" -Passed $false -Message "Unexpected error: $errorMsg"
    }
} else {
    Write-TestResult -TestName "TEST 1: Quantity Validation" -Passed $false -Message "Expected 400 error but got: $($test1Response.StatusCode)"
}

# TEST 2: Invalid Quantity (0)
Write-Host "`n[TEST 2] Invalid Quantity (0)..." -ForegroundColor Cyan
$test2Body = @{
    institutionId = $institutionId
    orderItems = @(
        @{
            performanceId = $performanceId
            quantity = 0
        }
    )
} | ConvertTo-Json

$test2Response = Invoke-ApiRequest -Method "POST" -Endpoint "/orders" -Token $token -Body ($test2Body | ConvertFrom-Json)

if (-not $test2Response.Success -and $test2Response.StatusCode -eq 400) {
    $errorMsg = $test2Response.Error.message
    if ($errorMsg -like "*Količina karata mora biti veća od 0*" -or $errorMsg -like "*quantity*") {
        Write-TestResult -TestName "TEST 2: Invalid Quantity (0)" -Passed $true -Message $errorMsg
    } else {
        Write-TestResult -TestName "TEST 2: Invalid Quantity (0)" -Passed $false -Message "Unexpected error: $errorMsg"
    }
} else {
    Write-TestResult -TestName "TEST 2: Invalid Quantity (0)" -Passed $false -Message "Expected 400 error but got: $($test2Response.StatusCode)"
}

# TEST 3: Invalid Performance ID
Write-Host "`n[TEST 3] Invalid Performance ID..." -ForegroundColor Cyan
$test3Body = @{
    institutionId = $institutionId
    orderItems = @(
        @{
            performanceId = 99999  # Non-existent
            quantity = 1
        }
    )
} | ConvertTo-Json

$test3Response = Invoke-ApiRequest -Method "POST" -Endpoint "/orders" -Token $token -Body ($test3Body | ConvertFrom-Json)

if (-not $test3Response.Success -and ($test3Response.StatusCode -eq 400 -or $test3Response.StatusCode -eq 404)) {
    Write-TestResult -TestName "TEST 3: Invalid Performance ID" -Passed $true -Message "Correctly rejected non-existent performance"
} else {
    Write-TestResult -TestName "TEST 3: Invalid Performance ID" -Passed $false -Message "Expected 400/404 error but got: $($test3Response.StatusCode)"
}

# TEST 4: Successful Order Creation (small quantity)
Write-Host "`n[TEST 4] Successful Order Creation..." -ForegroundColor Cyan
$quantity = [Math]::Min(2, [Math]::Floor($availableSeats / 2))
$test4Body = @{
    institutionId = $institutionId
    orderItems = @(
        @{
            performanceId = $performanceId
            quantity = $quantity
        }
    )
} | ConvertTo-Json

$test4Response = Invoke-ApiRequest -Method "POST" -Endpoint "/orders" -Token $token -Body ($test4Body | ConvertFrom-Json)

if ($test4Response.Success) {
    $orderId = $test4Response.Data.id
    Write-TestResult -TestName "TEST 4: Successful Order Creation" -Passed $true -Message "Order created with ID: $orderId, Quantity: $quantity"
    
    # Check order status
    $orderCheckResponse = Invoke-ApiRequest -Method "GET" -Endpoint "/orders/$orderId" -Token $token
    if ($orderCheckResponse.Success -and $orderCheckResponse.Data.status -eq "Pending") {
        Write-TestResult -TestName "TEST 4: Order Status = Pending" -Passed $true -Message "Order status is correctly set to Pending"
    } else {
        Write-TestResult -TestName "TEST 4: Order Status = Pending" -Passed $false -Message "Order status is not Pending"
    }
    
    # TEST 4b: Check Tickets (should be empty before payment)
    $ticketsResponse = Invoke-ApiRequest -Method "GET" -Endpoint "/orders/$orderId/tickets" -Token $token
    if ($ticketsResponse.Success -and $ticketsResponse.Data.Count -eq 0) {
        Write-TestResult -TestName "TEST 4b: No Tickets Before Payment" -Passed $true -Message "Correctly returns empty tickets list before payment"
    } else {
        Write-TestResult -TestName "TEST 4b: No Tickets Before Payment" -Passed $false -Message "Tickets exist before payment or error occurred"
    }
} else {
    Write-TestResult -TestName "TEST 4: Successful Order Creation" -Passed $false -Message "Failed to create order: $($test4Response.Exception)"
    $orderId = $null
}

# TEST 5: Check AvailableSeats decreased (after order creation, seats are still available until payment)
Write-Host "`n[TEST 5] AvailableSeats Check..." -ForegroundColor Cyan
$performanceCheckResponse = Invoke-ApiRequest -Method "GET" -Endpoint "/performances/$performanceId" -Token $token
if ($performanceCheckResponse.Success) {
    $newAvailableSeats = $performanceCheckResponse.Data.availableSeats
    if ($newAvailableSeats -eq $availableSeats) {
        Write-TestResult -TestName "TEST 5: AvailableSeats Not Decreased Before Payment" -Passed $true -Message "AvailableSeats correctly remains $availableSeats (seats not reserved until payment)"
    } else {
        Write-TestResult -TestName "TEST 5: AvailableSeats Not Decreased Before Payment" -Passed $false -Message "AvailableSeats changed from $availableSeats to $newAvailableSeats (should remain same until payment)"
    }
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
$passed = ($results | Where-Object { $_.Passed -eq $true }).Count
$failed = ($results | Where-Object { $_.Passed -eq $false }).Count
$total = $results.Count

Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $results | Where-Object { $_.Passed -eq $false } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
    }
}

# Export results to JSON
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath "test-results-faza3-$(Get-Date -Format 'yyyyMMdd-HHmmss').json" -Encoding UTF8
Write-Host "`nResults exported to test-results-faza3-*.json" -ForegroundColor Gray

Write-Host "`n=== END OF TESTS ===" -ForegroundColor Cyan

