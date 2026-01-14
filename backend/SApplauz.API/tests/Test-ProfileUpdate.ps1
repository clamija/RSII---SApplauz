# Test skripta za izmjenu profila
# Datum: 2025-01-06

$ErrorActionPreference = "Stop"

#$baseUrl = "http://localhost:5169/api"
#	$testUserEmail = "mobile"
#$testUserPassword = "test"

# Promijeni ove linije u Test-ProfileUpdate.ps1:

$baseUrl = "http://localhost:5000/api"  # Promijenjeno sa 5169 na 5000
$testUserEmail = "mobile@sapplauz.ba"   # Promijenjeno sa "mobile" (dodan @sapplauz.ba)
$testUserPassword = "Test12"            # Promijenjeno sa "test" na "Test12"

$token = $null

Write-Host "=== Test Izmjene Profila ===" -ForegroundColor Cyan
Write-Host ""

# 1. Login kao test korisnik
Write-Host "1. Prijava kao test korisnik..." -ForegroundColor Yellow
try {
    $loginBody = @{
        email = $testUserEmail
        password = $testUserPassword
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.token
    
    Write-Host "   ✅ Prijava uspješna" -ForegroundColor Green
    Write-Host "   Korisnik: $($loginResponse.user.email)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "   ❌ Greška pri prijavi: $_" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 2. Dobij trenutni profil
Write-Host "2. Dohvatanje trenutnog profila..." -ForegroundColor Yellow
try {
    $currentUser = Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Get -Headers $headers
    Write-Host "   ✅ Profil dohvaćen" -ForegroundColor Green
    Write-Host "   Ime: $($currentUser.firstName) $($currentUser.lastName)" -ForegroundColor Gray
    Write-Host "   Email: $($currentUser.email)" -ForegroundColor Gray
    Write-Host ""
    
    $originalFirstName = $currentUser.firstName
    $originalLastName = $currentUser.lastName
    $originalEmail = $currentUser.email
} catch {
    Write-Host "   ❌ Greška pri dohvatanju profila: $_" -ForegroundColor Red
    exit 1
}

# Test 1: Ažuriranje osnovnih podataka bez promjene lozinke
Write-Host "=== Test 1: Ažuriranje osnovnih podataka (bez lozinke) ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = "TestIme"
        lastName = "TestPrezime"
        email = $originalEmail  # Zadržavamo originalni email
    } | ConvertTo-Json

    $updatedUser = Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers
    
    Write-Host "   ✅ Ažuriranje uspješno" -ForegroundColor Green
    Write-Host "   Ime: $($updatedUser.firstName) $($updatedUser.lastName)" -ForegroundColor Gray
    Write-Host "   Email: $($updatedUser.email)" -ForegroundColor Gray
    
    # Provjeri da li su podaci ažurirani
    if ($updatedUser.firstName -eq "TestIme" -and $updatedUser.lastName -eq "TestPrezime") {
        Write-Host "   ✅ Podaci su ispravno ažurirani" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Podaci nisu ispravno ažurirani" -ForegroundColor Red
    }
    Write-Host ""
} catch {
    Write-Host "   ❌ Greška pri ažuriranju: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "   Response: $responseBody" -ForegroundColor Red
    }
    Write-Host ""
}

# Vrati originalne podatke
Write-Host "   Vraćanje originalnih podataka..." -ForegroundColor Yellow
try {
    $restoreBody = @{
        firstName = $originalFirstName
        lastName = $originalLastName
        email = $originalEmail
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $restoreBody -Headers $headers | Out-Null
    Write-Host "   ✅ Originalni podaci vraćeni" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Greška pri vraćanju originalnih podataka: $_" -ForegroundColor Yellow
    Write-Host ""
}

# Test 2: Validacija - pokušaj promjene lozinke bez trenutne lozinke
Write-Host "=== Test 2: Validacija - Promjena lozinke bez trenutne lozinke ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = $originalFirstName
        lastName = $originalLastName
        email = $originalEmail
        newPassword = "novaLozinka123"
        # currentPassword nije poslan
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers | Out-Null
        Write-Host "   ❌ Trebalo bi vratiti grešku - promjena lozinke bez trenutne lozinke" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Write-Host "   ✅ Validacija radi - vraćena je greška (400 Bad Request)" -ForegroundColor Green
            Write-Host "   Poruka: $_" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Neočekivana greška: Status $statusCode" -ForegroundColor Yellow
        }
    }
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Neočekivana greška: $_" -ForegroundColor Yellow
    Write-Host ""
}

# Test 3: Validacija - pokušaj promjene lozinke sa netačnom trenutnom lozinkom
Write-Host "=== Test 3: Validacija - Promjena lozinke sa netačnom trenutnom lozinkom ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = $originalFirstName
        lastName = $originalLastName
        email = $originalEmail
        currentPassword = "netacnaLozinka"
        newPassword = "novaLozinka123"
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers | Out-Null
        Write-Host "   ❌ Trebalo bi vratiti grešku - netačna trenutna lozinka" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Write-Host "   ✅ Validacija radi - vraćena je greška (400 Bad Request)" -ForegroundColor Green
            Write-Host "   Poruka: $_" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Neočekivana greška: Status $statusCode" -ForegroundColor Yellow
        }
    }
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Neočekivana greška: $_" -ForegroundColor Yellow
    Write-Host ""
}

# Test 4: Validacija - pokušaj promjene lozinke sa lozinkom manjom od 6 karaktera
Write-Host "=== Test 4: Validacija - Promjena lozinke sa lozinkom manjom od 6 karaktera ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = $originalFirstName
        lastName = $originalLastName
        email = $originalEmail
        currentPassword = $testUserPassword
        newPassword = "12345"  # Manje od 6 karaktera
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers | Out-Null
        Write-Host "   ❌ Trebalo bi vratiti grešku - lozinka manja od 6 karaktera" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Write-Host "   ✅ Validacija radi - vraćena je greška (400 Bad Request)" -ForegroundColor Green
            Write-Host "   Poruka: $_" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Neočekivana greška: Status $statusCode" -ForegroundColor Yellow
        }
    }
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Neočekivana greška: $_" -ForegroundColor Yellow
    Write-Host ""
}

# Test 5: Validacija - pokušaj promjene emaila sa nevalidnim formatom
Write-Host "=== Test 5: Validacija - Promjena emaila sa nevalidnim formatom ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = $originalFirstName
        lastName = $originalLastName
        email = "nevalidanEmail"  # Nevalidan email format
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers | Out-Null
        Write-Host "   ❌ Trebalo bi vratiti grešku - nevalidan email format" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Write-Host "   ✅ Validacija radi - vraćena je greška (400 Bad Request)" -ForegroundColor Green
            Write-Host "   Poruka: $_" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Neočekivana greška: Status $statusCode" -ForegroundColor Yellow
        }
    }
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Neočekivana greška: $_" -ForegroundColor Yellow
    Write-Host ""
}

# Test 6: Validacija - prazna polja
Write-Host "=== Test 6: Validacija - Prazna obavezna polja ===" -ForegroundColor Cyan
try {
    $updateBody = @{
        firstName = ""
        lastName = ""
        email = ""
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/users/me" -Method Put -Body $updateBody -Headers $headers | Out-Null
        Write-Host "   ❌ Trebalo bi vratiti grešku - prazna obavezna polja" -ForegroundColor Red
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Write-Host "   ✅ Validacija radi - vraćena je greška (400 Bad Request)" -ForegroundColor Green
            Write-Host "   Poruka: $_" -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Neočekivana greška: Status $statusCode" -ForegroundColor Yellow
        }
    }
    Write-Host ""
} catch {
    Write-Host "   ⚠️  Neočekivana greška: $_" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=== Testiranje završeno ===" -ForegroundColor Cyan
