# FAZA 3: Backend - Real-time provjera dostupnosti i checkout sigurnost
# Jednostavna PowerShell skripta za testiranje

param(
    [string]$ApiUrl = "http://localhost:5169/api"
)

Write-Host "`n=== FAZA 3: Backend Checkout Security Tests ===" -ForegroundColor Cyan
Write-Host "API URL: $ApiUrl`n" -ForegroundColor Gray

# Provjera da li API radi
Write-Host "[CHECK] Testing API availability..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/performances" -Method GET -TimeoutSec 3 -ErrorAction Stop
    Write-Host "✅ API is running and accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ API is not running or not accessible at $ApiUrl" -ForegroundColor Red
    Write-Host "Please start the API with: dotnet run --project SApplauz.API/SApplauz.API.csproj" -ForegroundColor Yellow
    exit 1
}

# Login
Write-Host "`n[SETUP] Logging in as user@sapplauz.ba..." -ForegroundColor Yellow
$loginBody = @{
    email = "user@sapplauz.ba"
    password = "User123!"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$ApiUrl/auth/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    $token = $loginResponse.token
    Write-Host "✅ Login successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get Performances
Write-Host "`n[SETUP] Getting available performances..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    $performances = Invoke-RestMethod -Uri "$ApiUrl/performances" -Method GET -Headers $headers -ErrorAction Stop
    $testPerformance = $performances | Where-Object { $_.availableSeats -gt 0 } | Select-Object -First 1
    
    if (-not $testPerformance) {
        Write-Host "⚠️  No performances with available seats found" -ForegroundColor Yellow
        exit 1
    }
    
    $performanceId = $testPerformance.id
    $showId = $testPerformance.showId
    $availableSeats = $testPerformance.availableSeats
    
    # Get Show to get InstitutionId
    $show = Invoke-RestMethod -Uri "$ApiUrl/shows/$showId" -Method GET -Headers $headers -ErrorAction Stop
    $institutionId = $show.institutionId
    
    Write-Host "✅ Found performance ID: $performanceId with $availableSeats available seats" -ForegroundColor Green
    Write-Host "   InstitutionId: $institutionId" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to get performances: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$testResults = @()

# TEST 1: Quantity Validation - Too many tickets
Write-Host "`n[TEST 1] Quantity Validation - Too many tickets..." -ForegroundColor Cyan
try {
    $test1Body = @{
        institutionId = $institutionId
        orderItems = @(
            @{
                performanceId = $performanceId
                quantity = 10000
            }
        )
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "$ApiUrl/orders" -Method POST -Headers $headers -Body $test1Body -ErrorAction Stop | Out-Null
    Write-Host "❌ TEST 1 FAILED: Expected 400 error but order was created" -ForegroundColor Red
    $testResults += @{ Test = "TEST 1: Quantity Validation"; Passed = $false; Message = "Order was created but should have been rejected" }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $null
    $errorMessage = ""
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        $reader.Close()
        $errorBody = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
        $errorMessage = if ($errorBody.errors) { ($errorBody.errors.PSObject.Properties | ForEach-Object { $_.Value -join "; " }) -join " | " } elseif ($errorBody.message) { $errorBody.message } else { $responseBody }
    } else {
        $errorMessage = $_.Exception.Message
    }
    
    if ($statusCode -eq 400 -and ($errorMessage -like "*Neko je bio brži*" -or $errorMessage -like "*preostalo samo*" -or $errorMessage -like "*Maksimalna*" -or $errorMessage -like "*maksimalna*" -or $errorMessage -like "*20 karata*")) {
        Write-Host "✅ TEST 1 PASSED: Correctly rejected too many tickets" -ForegroundColor Green
        Write-Host "   Message: $errorMessage" -ForegroundColor Gray
        $testResults += @{ Test = "TEST 1: Quantity Validation"; Passed = $true; Message = $errorMessage }
    } else {
        Write-Host "❌ TEST 1 FAILED: Unexpected error (Status: $statusCode)" -ForegroundColor Red
        Write-Host "   Error: $errorMessage" -ForegroundColor Yellow
        $testResults += @{ Test = "TEST 1: Quantity Validation"; Passed = $false; Message = "Status: $statusCode, Error: $errorMessage" }
    }
}

# TEST 2: Invalid Quantity (0)
Write-Host "`n[TEST 2] Invalid Quantity (0)..." -ForegroundColor Cyan
try {
    $test2Body = @{
        institutionId = $institutionId
        orderItems = @(
            @{
                performanceId = $performanceId
                quantity = 0
            }
        )
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "$ApiUrl/orders" -Method POST -Headers $headers -Body $test2Body -ErrorAction Stop | Out-Null
    Write-Host "❌ TEST 2 FAILED: Expected 400 error but order was created" -ForegroundColor Red
    $testResults += @{ Test = "TEST 2: Invalid Quantity (0)"; Passed = $false; Message = "Order was created but should have been rejected" }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = $null
    $errorMessage = ""
    
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        $reader.Close()
        $errorBody = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
        $errorMessage = if ($errorBody.errors) { ($errorBody.errors.PSObject.Properties | ForEach-Object { $_.Value -join "; " }) -join " | " } elseif ($errorBody.message) { $errorBody.message } else { $responseBody }
    } else {
        $errorMessage = $_.Exception.Message
    }
    
    if ($statusCode -eq 400 -and ($errorMessage -like "*Količina karata mora biti veća od 0*" -or $errorMessage -like "*Kolicina mora biti*" -or $errorMessage -like "*quantity*" -or $errorMessage -like "*mora biti*" -or $errorMessage -like "*veća od 0*" -or $errorMessage -like "*veca od 0*" -or $errorMessage -like "*veća od 0*" -or $errorMessage.Contains("veca") -or $errorMessage.Contains("veća"))) {
        Write-Host "✅ TEST 2 PASSED: Correctly rejected quantity = 0" -ForegroundColor Green
        Write-Host "   Message: $errorMessage" -ForegroundColor Gray
        $testResults += @{ Test = "TEST 2: Invalid Quantity (0)"; Passed = $true; Message = $errorMessage }
    } else {
        Write-Host "❌ TEST 2 FAILED: Unexpected error (Status: $statusCode)" -ForegroundColor Red
        Write-Host "   Error: $errorMessage" -ForegroundColor Yellow
        $testResults += @{ Test = "TEST 2: Invalid Quantity (0)"; Passed = $false; Message = "Status: $statusCode, Error: $errorMessage" }
    }
}

# TEST 3: Invalid Performance ID
Write-Host "`n[TEST 3] Invalid Performance ID..." -ForegroundColor Cyan
try {
    $test3Body = @{
        institutionId = $institutionId
        orderItems = @(
            @{
                performanceId = 99999
                quantity = 1
            }
        )
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri "$ApiUrl/orders" -Method POST -Headers $headers -Body $test3Body -ErrorAction Stop | Out-Null
    Write-Host "❌ TEST 3 FAILED: Expected 400/404 error but order was created" -ForegroundColor Red
    $testResults += @{ Test = "TEST 3: Invalid Performance ID"; Passed = $false; Message = "Order was created but should have been rejected" }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400 -or $statusCode -eq 404) {
        Write-Host "✅ TEST 3 PASSED: Correctly rejected non-existent performance" -ForegroundColor Green
        $testResults += @{ Test = "TEST 3: Invalid Performance ID"; Passed = $true; Message = "Correctly rejected" }
    } else {
        Write-Host "❌ TEST 3 FAILED: Unexpected error (Status: $statusCode)" -ForegroundColor Red
        $testResults += @{ Test = "TEST 3: Invalid Performance ID"; Passed = $false; Message = "Unexpected status code: $statusCode" }
    }
}

# TEST 4: Successful Order Creation
Write-Host "`n[TEST 4] Successful Order Creation..." -ForegroundColor Cyan
try {
    $quantity = [Math]::Min(2, [Math]::Floor($availableSeats / 2))
    if ($quantity -lt 1) {
        Write-Host "⚠️  TEST 4 SKIPPED: Not enough available seats for test" -ForegroundColor Yellow
        $testResults += @{ Test = "TEST 4: Successful Order Creation"; Passed = $false; Message = "Skipped - not enough seats" }
    } else {
        $test4Body = @{
            institutionId = $institutionId
            orderItems = @(
                @{
                    performanceId = $performanceId
                    quantity = $quantity
                }
            )
        } | ConvertTo-Json
        
        $orderResponse = Invoke-RestMethod -Uri "$ApiUrl/orders" -Method POST -Headers $headers -Body $test4Body -ErrorAction Stop
        $orderId = $orderResponse.id
        
        if ($orderResponse.status -eq "Pending") {
            Write-Host "✅ TEST 4 PASSED: Order created with ID: $orderId, Quantity: $quantity, Status: Pending" -ForegroundColor Green
            $testResults += @{ Test = "TEST 4: Successful Order Creation"; Passed = $true; Message = "Order ID: $orderId" }
            
            # Check tickets (should be empty before payment)
            $ticketsResponse = Invoke-RestMethod -Uri "$ApiUrl/orders/$orderId/tickets" -Method GET -Headers $headers -ErrorAction Stop
            if ($ticketsResponse.Count -eq 0) {
                Write-Host "✅ TEST 4b PASSED: No tickets before payment (correct)" -ForegroundColor Green
                $testResults += @{ Test = "TEST 4b: No Tickets Before Payment"; Passed = $true; Message = "Correctly empty" }
            } else {
                Write-Host "❌ TEST 4b FAILED: Tickets exist before payment" -ForegroundColor Red
                $testResults += @{ Test = "TEST 4b: No Tickets Before Payment"; Passed = $false; Message = "Tickets should not exist before payment" }
            }
        } else {
            Write-Host "❌ TEST 4 FAILED: Order created but status is not Pending" -ForegroundColor Red
            $testResults += @{ Test = "TEST 4: Successful Order Creation"; Passed = $false; Message = "Status: $($orderResponse.status)" }
        }
    }
} catch {
    Write-Host "❌ TEST 4 FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "TEST 4: Successful Order Creation"; Passed = $false; Message = $_.Exception.Message }
}

# TEST 5: AvailableSeats Check (should not change before payment)
Write-Host "`n[TEST 5] AvailableSeats Check (before payment)..." -ForegroundColor Cyan
try {
    $performanceCheck = Invoke-RestMethod -Uri "$ApiUrl/performances/$performanceId" -Method GET -Headers $headers -ErrorAction Stop
    if ($performanceCheck.availableSeats -eq $availableSeats) {
        Write-Host "✅ TEST 5 PASSED: AvailableSeats correctly remains $availableSeats (seats not reserved until payment)" -ForegroundColor Green
        $testResults += @{ Test = "TEST 5: AvailableSeats Not Decreased Before Payment"; Passed = $true; Message = "Seats correctly not reserved" }
    } else {
        Write-Host "❌ TEST 5 FAILED: AvailableSeats changed from $availableSeats to $($performanceCheck.availableSeats)" -ForegroundColor Red
        $testResults += @{ Test = "TEST 5: AvailableSeats Not Decreased Before Payment"; Passed = $false; Message = "Should remain same until payment" }
    }
} catch {
    Write-Host "❌ TEST 5 FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $testResults += @{ Test = "TEST 5: AvailableSeats Not Decreased Before Payment"; Passed = $false; Message = $_.Exception.Message }
}

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
$passed = ($testResults | Where-Object { $_.Passed -eq $true }).Count
$failed = ($testResults | Where-Object { $_.Passed -eq $false }).Count
$total = $testResults.Count

Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $testResults | Where-Object { $_.Passed -eq $false } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== END OF TESTS ===" -ForegroundColor Cyan

# Export results
$resultsJson = $testResults | ConvertTo-Json -Depth 3
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultsFile = "test-results-faza3-$timestamp.json"
$resultsJson | Out-File -FilePath $resultsFile -Encoding UTF8
Write-Host "Results exported to: $resultsFile" -ForegroundColor Gray

