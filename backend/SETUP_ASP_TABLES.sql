-- ============================================================================
-- SQL SKRIPTA ZA POSTAVLJANJE ASP.NET IDENTITY TABELA
-- ============================================================================
-- Ova skripta:
-- 1. Briše sve postojeće podatke iz ASP.NET Identity tabela
-- 2. Dodaje sve potrebne uloge (roles)
-- 3. Ostavlja tabele spremne za seed korisnike (koji će se kreirati kroz kod)
-- ============================================================================

USE [210107];
GO

-- ============================================================================
-- KORAK 1: BRISANJE POSTOJEĆIH PODATAKA (U PRAVOM REDOSLJEDU!)
-- ============================================================================
-- VAŽNO: Redosljed brisanja je ključan zbog foreign key constrainta!
-- Prvo brišemo tabele koje referenciraju korisnike, pa tek onda korisnike!

PRINT 'Brisanje postojećih podataka...';
PRINT '';

-- PRVO: Najdublje tabele (najviše dependencija)
PRINT 'Brisanje Tickets...';
DELETE FROM Tickets;
PRINT '  ✓ Tickets obrisani';

PRINT 'Brisanje OrderItems...';
DELETE FROM OrderItems;
PRINT '  ✓ OrderItems obrisani';

PRINT 'Brisanje Payments...';
DELETE FROM Payments;
PRINT '  ✓ Payments obrisani';

PRINT 'Brisanje Orders...';
DELETE FROM Orders;
PRINT '  ✓ Orders obrisani';

-- DRUGO: Tabele koje zavise od korisnika
PRINT 'Brisanje Reviews...';
DELETE FROM Reviews;
PRINT '  ✓ Reviews obrisani';

PRINT 'Brisanje RecommendationProfiles...';
DELETE FROM RecommendationProfiles;
PRINT '  ✓ RecommendationProfiles obrisani';

-- TREĆE: Tabele koje zavise od ostalih (za čišćenje svega)
-- Napomena: ShowGenres tabela više ne postoji (GenreId je direktno u Shows)

PRINT 'Brisanje Performances...';
DELETE FROM Performances;
PRINT '  ✓ Performances obrisani';

PRINT 'Brisanje Shows...';
DELETE FROM Shows;
PRINT '  ✓ Shows obrisani';

PRINT 'Brisanje Genres...';
DELETE FROM Genres;
PRINT '  ✓ Genres obrisani';

PRINT 'Brisanje Institutions...';
DELETE FROM Institutions;
PRINT '  ✓ Institutions obrisani';

-- ČETVRTO: ASP.NET Identity tabele (NA KRAJU - nakon što su sve veze obrisane!)
PRINT 'Brisanje ASP.NET Identity tabela...';
DELETE FROM AspNetUserRoles;
PRINT '  ✓ AspNetUserRoles obrisani';
DELETE FROM AspNetUserClaims;
PRINT '  ✓ AspNetUserClaims obrisani';
DELETE FROM AspNetUserLogins;
PRINT '  ✓ AspNetUserLogins obrisani';
DELETE FROM AspNetUserTokens;
PRINT '  ✓ AspNetUserTokens obrisani';
DELETE FROM AspNetRoleClaims;
PRINT '  ✓ AspNetRoleClaims obrisani';
DELETE FROM AspNetUsers;
PRINT '  ✓ AspNetUsers obrisani';
DELETE FROM AspNetRoles;
PRINT '  ✓ AspNetRoles obrisani';

PRINT '';
PRINT 'Svi podaci su obrisani!';
PRINT '';
GO

-- ============================================================================
-- KORAK 2: DODAVANJE ULOGA (ROLES)
-- ============================================================================

PRINT 'Dodavanje uloga...';
PRINT '';

-- Osnovne uloge (samo ako ne postoje)
IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'superadmin')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (NEWID(), 'superadmin', 'SUPERADMIN', NEWID());
    PRINT '  ✓ Dodana uloga: superadmin';
END
ELSE
BEGIN
    PRINT '  ⊗ Uloga superadmin već postoji, preskačem';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'korisnik')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp)
    VALUES (NEWID(), 'korisnik', 'KORISNIK', NEWID());
    PRINT '  ✓ Dodana uloga: korisnik';
END
ELSE
BEGIN
    PRINT '  ⊗ Uloga korisnik već postoji, preskačem';
END

-- Admin uloge za institucije (samo ako ne postoje)
IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminNPS')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminNPS', 'ADMINNPS', NEWID());
    PRINT '  ✓ Dodana uloga: adminNPS';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminKT')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminKT', 'ADMINKT', NEWID());
    PRINT '  ✓ Dodana uloga: adminKT';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminSARTR')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminSARTR', 'ADMINSARTR', NEWID());
    PRINT '  ✓ Dodana uloga: adminSARTR';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminPOZM')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminPOZM', 'ADMINPOZM', NEWID());
    PRINT '  ✓ Dodana uloga: adminPOZM';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminOS')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminOS', 'ADMINOS', NEWID());
    PRINT '  ✓ Dodana uloga: adminOS';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminCK')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminCK', 'ADMINCK', NEWID());
    PRINT '  ✓ Dodana uloga: adminCK';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminBKC')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminBKC', 'ADMINBKC', NEWID());
    PRINT '  ✓ Dodana uloga: adminBKC';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'adminDM')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'adminDM', 'ADMINDM', NEWID());
    PRINT '  ✓ Dodana uloga: adminDM';
END

PRINT '';

-- Blagajnik uloge za institucije (samo ako ne postoje)
IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikNPS')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikNPS', 'BLAGAJNIKNPS', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikNPS';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikKT')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikKT', 'BLAGAJNIKKT', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikKT';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikSARTR')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikSARTR', 'BLAGAJNIKSARTR', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikSARTR';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikPOZM')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikPOZM', 'BLAGAJNIKPOZM', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikPOZM';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikOS')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikOS', 'BLAGAJNIKOS', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikOS';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikCK')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikCK', 'BLAGAJNIKCK', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikCK';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikBKC')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikBKC', 'BLAGAJNIKBKC', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikBKC';
END

IF NOT EXISTS (SELECT 1 FROM AspNetRoles WHERE Name = 'blagajnikDM')
BEGIN
    INSERT INTO AspNetRoles (Id, Name, NormalizedName, ConcurrencyStamp) VALUES (NEWID(), 'blagajnikDM', 'BLAGAJNIKDM', NEWID());
    PRINT '  ✓ Dodana uloga: blagajnikDM';
END

PRINT '';
PRINT 'Dodavanje uloga završeno!';
GO

-- ============================================================================
-- KORAK 3: PROVJERA
-- ============================================================================

PRINT '';
PRINT '============================================================================';
PRINT 'PROVJERA: Sve uloge su dodane:';
PRINT '============================================================================';

SELECT 
    Name AS 'Uloga',
    NormalizedName AS 'Normalizovano ime'
FROM AspNetRoles
ORDER BY Name;

-- Provjera broja uloga
DECLARE @RoleCount INT;
SELECT @RoleCount = COUNT(*) FROM AspNetRoles;

PRINT '';
PRINT 'Ukupno uloga: ' + CAST(@RoleCount AS VARCHAR);
PRINT '';
PRINT '============================================================================';
PRINT 'ASP.NET Identity tabele su spremne!';
PRINT 'Korisnici će se automatski kreirati kada pokrenete API (seed kod).';
PRINT '============================================================================';
GO

