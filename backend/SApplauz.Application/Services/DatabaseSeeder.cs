using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Constants;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using System.Text.Json;

namespace SApplauz.Application.Services;

public class DatabaseSeeder : IDatabaseSeeder
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly ILogger<DatabaseSeeder> _logger;

    public DatabaseSeeder(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole> roleManager,
        ILogger<DatabaseSeeder> logger)
    {
        _context = context;
        _userManager = userManager;
        _roleManager = roleManager;
        _logger = logger;
    }

    public async Task SeedAsync()
    {
        try
        {
            _logger.LogInformation("=== Starting database seeding ===");

            try
            {
                await _context.Database.MigrateAsync();
                _logger.LogInformation("Database migrations completed.");
            }
            catch (SqlException ex) when (ex.Number == 2714 || ex.Message.Contains("already an object named 'AspNetRoles'", StringComparison.OrdinalIgnoreCase))
            {
                // Dev scenario: baza je već ručno/ranije kreirana bez __EFMigrationsHistory,
                // pa EF pokušava ponovo kreirati Identity tabele i pukne.
                // Ne želimo da API padne (Swagger 500), pa u tom slučaju nastavljamo bez migracija.
                _logger.LogWarning(ex, "MigrateAsync failed because tables already exist. Continuing without applying migrations.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database migrations failed.");
                throw;
            }

            _logger.LogInformation("Seeding roles...");
            await SeedRolesAsync();

            _logger.LogInformation("=== Calling SeedGenresAsync ===");
            await SeedGenresAsync();

            _logger.LogInformation("=== Calling SeedInstitutionsAsync ===");
            await SeedInstitutionsAsync();

            _logger.LogInformation("Seeding users...");
            await SeedUsersAsync();

            _logger.LogInformation("=== Calling SeedShowsAsync ===");
            await SeedShowsAsync();

            _logger.LogInformation("=== Calling SeedPerformancesAsync ===");
            await SeedPerformancesAsync();

            _logger.LogInformation("=== Calling SeedOrdersTicketsReviewsAsync ===");
            await SeedOrdersTicketsReviewsAsync();

            _logger.LogInformation("=== Database seeding completed successfully ===");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An error occurred while seeding the database. Exception: {Message}, StackTrace: {StackTrace}", ex.Message, ex.StackTrace);
            throw;
        }
    }

    private async Task SeedRolesAsync()
    {
        var roles = ApplicationRoles.GetAllRoles();

        foreach (var roleName in roles)
        {
            var roleExists = await _roleManager.RoleExistsAsync(roleName);
            if (!roleExists)
            {
                var role = new IdentityRole(roleName)
                {
                    NormalizedName = roleName.ToUpper()
                };
                await _roleManager.CreateAsync(role);
                _logger.LogInformation("Created role: {RoleName}", roleName);
            }
        }
    }

    private async Task SeedUsersAsync()
    {
        // Dinamički resolve ID-eva institucija po nazivu (ne pretpostavljamo da su 1..8).
        async Task<int?> InstId(string name)
        {
            var inst = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == name);
            return inst?.Id;
        }

        var npsId = await InstId("Narodno pozorište Sarajevo");
        var ktId = await InstId("Kamerni teatar 55");
        var sartrId = await InstId("Sarajevski ratni teatar");
        var pozmId = await InstId("Pozorište mladih Sarajevo");
        var osId = await InstId("Otvorena scena Obala");
        var ckId = await InstId("JU Centar kulture i mladih");
        var bkcId = await InstId("Bosanski kulturni centar");
        var dmId = await InstId("Dom mladih Skenderija");

        await CreateUserIfNotExistsAsync(
            username: "superadmin",
            email: "superadmin@sapplauz.ba",
            password: "test",
            firstName: "Super",
            lastName: "Admin",
            role: ApplicationRoles.SuperAdmin
        );

        await CreateUserIfNotExistsAsync(
            username: "adminNPS",
            email: "adminNPS@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "NPS",
            role: ApplicationRoles.Admin,
            institutionId: npsId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminKT",
            email: "adminKT@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "KT",
            role: ApplicationRoles.Admin,
            institutionId: ktId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminSARTR",
            email: "adminSARTR@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "SARTR",
            role: ApplicationRoles.Admin,
            institutionId: sartrId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminPOZM",
            email: "adminPOZM@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "POZM",
            role: ApplicationRoles.Admin,
            institutionId: pozmId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminOS",
            email: "adminOS@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "OS",
            role: ApplicationRoles.Admin,
            institutionId: osId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminCK",
            email: "adminCK@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "CK",
            role: ApplicationRoles.Admin,
            institutionId: ckId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminBKC",
            email: "adminBKC@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "BKC",
            role: ApplicationRoles.Admin,
            institutionId: bkcId
        );

        await CreateUserIfNotExistsAsync(
            username: "adminDM",
            email: "adminDM@sapplauz.ba",
            password: "test",
            firstName: "Admin",
            lastName: "DM",
            role: ApplicationRoles.Admin,
            institutionId: dmId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikNPS",
            email: "blagajnikNPS@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "NPS",
            role: ApplicationRoles.Blagajnik,
            institutionId: npsId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikKT",
            email: "blagajnikKT@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "KT",
            role: ApplicationRoles.Blagajnik,
            institutionId: ktId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikSARTR",
            email: "blagajnikSARTR@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "SARTR",
            role: ApplicationRoles.Blagajnik,
            institutionId: sartrId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikPOZM",
            email: "blagajnikPOZM@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "POZM",
            role: ApplicationRoles.Blagajnik,
            institutionId: pozmId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikOS",
            email: "blagajnikOS@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "OS",
            role: ApplicationRoles.Blagajnik,
            institutionId: osId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikCK",
            email: "blagajnikCK@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "CK",
            role: ApplicationRoles.Blagajnik,
            institutionId: ckId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikBKC",
            email: "blagajnikBKC@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "BKC",
            role: ApplicationRoles.Blagajnik,
            institutionId: bkcId
        );

        await CreateUserIfNotExistsAsync(
            username: "blagajnikDM",
            email: "blagajnikDM@sapplauz.ba",
            password: "test",
            firstName: "Blagajnik",
            lastName: "DM",
            role: ApplicationRoles.Blagajnik,
            institutionId: dmId
        );

        await CreateUserIfNotExistsAsync(
            username: "mobile",
            email: "mobile@sapplauz.ba",
            password: "test",
            firstName: "Mobile",
            lastName: "User",
            role: ApplicationRoles.SuperAdmin
        );

        await CreateUserIfNotExistsAsync(
            username: "desktop",
            email: "desktop@sapplauz.ba",
            password: "test",
            firstName: "Desktop",
            lastName: "Admin",
            role: ApplicationRoles.SuperAdmin
        );

        for (var i = 1; i <= 6; i++)
        {
            await CreateUserIfNotExistsAsync(
                username: $"korisnik{i}",
                email: $"korisnik{i}@sapplauz.ba",
                password: "test",
                firstName: "Korisnik",
                lastName: i.ToString(),
                role: ApplicationRoles.Korisnik
            );
        }
    }

    private async Task CreateUserIfNotExistsAsync(
        string username,
        string email,
        string password,
        string firstName,
        string lastName,
        string role,
        int? institutionId = null)
    {
        var existingUser = await _userManager.FindByEmailAsync(email);
        if (existingUser != null)
        {
            var changed = false;
            if (!string.Equals(existingUser.UserName, username, StringComparison.Ordinal))
            {
                existingUser.UserName = username;
                existingUser.NormalizedUserName = username.ToUpperInvariant();
                changed = true;
            }
            if (!string.Equals(existingUser.FirstName, firstName, StringComparison.Ordinal))
            {
                existingUser.FirstName = firstName;
                changed = true;
            }
            if (!string.Equals(existingUser.LastName, lastName, StringComparison.Ordinal))
            {
                existingUser.LastName = lastName;
                changed = true;
            }
            if (existingUser.InstitutionId != institutionId)
            {
                existingUser.InstitutionId = institutionId;
                changed = true;
            }
            if (!existingUser.IsActive)
            {
                existingUser.IsActive = true;
                changed = true;
            }

            if (changed)
            {
                await _userManager.UpdateAsync(existingUser);
            }

            var resetToken = await _userManager.GeneratePasswordResetTokenAsync(existingUser);
            var resetResult = await _userManager.ResetPasswordAsync(existingUser, resetToken, password);
            if (!resetResult.Succeeded)
            {
                var errs = string.Join(", ", resetResult.Errors.Select(e => e.Description));
                _logger.LogWarning("Failed to reset password for {Email}: {Errors}", email, errs);
            }

            var roles = await _userManager.GetRolesAsync(existingUser);
            foreach (var r in roles.Where(r => !string.Equals(r, role, StringComparison.Ordinal)))
            {
                await _userManager.RemoveFromRoleAsync(existingUser, r);
            }
            if (!roles.Contains(role))
            {
                await _userManager.AddToRoleAsync(existingUser, role);
            }

            _logger.LogInformation("User {Email} already exists, synced username/password/role.", email);
            return;
        }

        var user = new ApplicationUser
        {
            UserName = username,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            EmailConfirmed = true,
            CreatedAt = DateTime.UtcNow,
            InstitutionId = institutionId
        };

        IdentityResult result;
        try
        {
            result = await _userManager.CreateAsync(user, password);
        }
        catch (DbUpdateException ex)
        {
            // Ne ruši seed ako je baza nekonzistentna (npr. FK na institucije).
            _logger.LogError(ex, "Failed to create user {Email} due to DB constraints.", email);
            return;
        }
        if (result.Succeeded)
        {
            await _userManager.AddToRoleAsync(user, role);
            _logger.LogInformation("Created user: {Email} with role: {Role} and InstitutionId: {InstitutionId}", 
                email, role, institutionId?.ToString() ?? "null");
        }
        else
        {
            var errors = string.Join(", ", result.Errors.Select(e => e.Description));
            _logger.LogError("Failed to create user {Email}: {Errors}", email, errors);
        }
    }

    private async Task SeedGenresAsync()
    {
        try
        {
            _logger.LogInformation("Starting SeedGenresAsync...");
            
            var requiredGenres = new[]
            {
                new { Name = "Drama", CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3000000") },
                new { Name = "Komedija", CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3000000") },
                new { Name = "Dječija predstava", CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3000000") },
                new { Name = "Balet", CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3000000") },
                new { Name = "Opera", CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3000000") }
            };

            var existingGenreNames = await _context.Genres
                .Select(g => g.Name)
                .ToListAsync();

            _logger.LogInformation("Found {Count} existing genres: {Genres}", existingGenreNames.Count, string.Join(", ", existingGenreNames));

            var missingGenres = requiredGenres
                .Where(g => !existingGenreNames.Contains(g.Name))
                .Select(g => new Genre
                {
                    Name = g.Name,
                    CreatedAt = g.CreatedAt
                })
                .ToList();

            _logger.LogInformation("Missing genres count: {Count}", missingGenres.Count);

            if (missingGenres.Any())
            {
                await _context.Genres.AddRangeAsync(missingGenres);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} missing genres: {Genres}", missingGenres.Count, string.Join(", ", missingGenres.Select(g => g.Name)));
            }
            else
            {
                _logger.LogInformation("All required genres already exist.");
            }

            // Cleanup: ukloni "Temporary" žanr ako postoji (ne želimo da se pojavljuje u aplikaciji).
            // Ako slučajno ima predstava, preveži ih na prvi "pravi" žanr i onda obriši.
            var temp = await _context.Genres
                .Include(g => g.Shows)
                .FirstOrDefaultAsync(g => g.Name == "Temporary");

            if (temp != null)
            {
                var fallback = await _context.Genres
                    .OrderBy(g => g.Id)
                    .FirstOrDefaultAsync(g => g.Id != temp.Id);

                if (temp.Shows.Any())
                {
                    if (fallback != null)
                    {
                        foreach (var s in temp.Shows)
                        {
                            s.GenreId = fallback.Id;
                        }
                    }
                }

                _context.Genres.Remove(temp);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Removed Temporary genre.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedGenresAsync");
            throw;
        }
    }

    private async Task SeedInstitutionsAsync()
    {
        try
        {
            _logger.LogInformation("Starting SeedInstitutionsAsync...");
            
            var requiredInstitutions = new[]
            {
            new
            {
                Name = "Narodno pozorište Sarajevo",
                Description = "Narodno pozorište Sarajevo centralna je i najznačajnija teatarska kuća u BiH, u sklopu koje djeluju Drama, Opera i Balet, a pod istim krovom nalazi se i Sarajevska filharmonija.",
                Address = "Obala Kulina bana 9, 71000 Sarajevo",
                Capacity = 432,
                ImagePath = "/images/nps.jpg",
                Website = "https://nps.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Kamerni teatar 55",
                Description = "Kamerni teatar 55 osnovao je 1955. godine u Sarajevu Jurislav Korenić, kao prostor novog i avangardnog teatarskog izraza, drugačijeg od tada dominantnog pozorišnog modela u Jugoslaviji. Tokom decenija, teatar je izgradio ugled institucije visokih umjetničkih standarda i snažne veze s publikom, nastupajući širom regiona i Evrope. Posebna intimnost scenskog prostora, naročito izražena tokom ratnih devedesetih, učinila je Kamerni teatar 55 simbolom duhovnog otpora i zajedništva.",
                Address = "Maršala Tita 55/II, 71000 Sarajevo",
                Capacity = 160,
                ImagePath = "/images/kt.jpg",
                Website = "https://www.kamerniteatar55.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Sarajevski ratni teatar",
                Description = "Najmlađa teatarska kuća u Sarajevu, Sarajevski ratni teatar SARTR, osnovana je 1992. godine tokom opsade Sarajeva i danas okuplja mlade teatarske radnike koji svakog mjeseca produciraju nove pozorišne predstave.",
                Address = "Gabelina 16, 71000 Sarajevo",
                Capacity = 250,
                ImagePath = "/images/sartr.jpg",
                Website = "https://sartr.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Pozorište mladih Sarajevo",
                Description = "Pozorište mladih Sarajevo, čiji repertoar nudi predstave za djecu, mlade, ali i odrasle, osnovano je 1977. godine udruživanjem Pionirskog pozorišta i Pozorišta lutaka.",
                Address = "Kulovića 8, 71000 Sarajevo",
                Capacity = 250,
                ImagePath = "/images/pozm.jpg",
                Website = "https://pozoristemladih.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Otvorena scena Obala",
                Description = "Otvorena scena Obala je alternativna pozorišna scena nastala pri Akademiji scenskih umjetnosti Sarajevo 1984. godine. Repertoar čine predstave studenata Akademije.",
                Address = "Obala Kulina bana 11, 71000 Sarajevo",
                Capacity = 130,
                ImagePath = "/images/os.jpg",
                Website = "https://www.asu.unsa.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "JU Centar kulture i mladih",
                Description = "Javna ustanova Centar kulture i mladih Općine Centar Sarajevo, osnovana je 1965. godine. Do 1992. godine objedinjavala je rad 13 domova kulture na području današnjih Općina Centar Sarajevo i Stari Grad i sa tridesetak zaposlenih bila jedna od najvećih ustanova ovog umjetničkog profila.",
                Address = "Jelića 1, 71000 Sarajevo",
                Capacity = 80,
                ImagePath = "/images/ck.jpg",
                Website = "https://centarkulture.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Bosanski kulturni centar",
                Description = "Bosanski kulturni centar, nekadašnji sefardski hram Templ, nalazi se u centru Sarajeva i predstavlja jedno od najznačajnijih kulturnih zdanja grada. Izgrađen 1930. godine prema projektu Rudolfa Lubinskog, Templ je 1948. godine poklonjen Sarajevu i prilagođen kulturnim potrebama prema projektu Ivana Štrausa. Danas je to savremeni kulturni centar sa koncertnom dvoranom vrhunske akustike i simbolima dugog jevrejskog naslijeđa u Sarajevu.",
                Address = "Branilaca Sarajeva 24, 71000 Sarajevo",
                Capacity = 800,
                ImagePath = "/images/bkc.jpg",
                Website = "https://bkc.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            },
            new
            {
                Name = "Dom mladih Skenderija",
                Description = "Dom mladih je multimedijalni prostor u kojem se redovno dešavaju različiti događaji, a koji je prevashodno namijenjen kulturno – umjetničkom stvaralaštvu mladih.",
                Address = "Terezije bb, 71000 Sarajevo",
                Capacity = 2000,
                ImagePath = "/images/dm.jpg",
                Website = "https://skenderija.ba/",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.2366667")
            }
        };

            var existingInstitutionNames = await _context.Institutions
                .Select(i => i.Name)
                .ToListAsync();

            _logger.LogInformation("Found {Count} existing institutions: {Institutions}", existingInstitutionNames.Count, string.Join(", ", existingInstitutionNames));

            var missingInstitutions = requiredInstitutions
                .Where(inst => !existingInstitutionNames.Contains(inst.Name))
                .Select(inst => new Institution
                {
                    Name = inst.Name,
                    Description = inst.Description,
                    Address = inst.Address,
                    Capacity = inst.Capacity,
                    ImagePath = inst.ImagePath,
                    Website = inst.Website,
                    IsActive = true,
                    CreatedAt = inst.CreatedAt
                })
                .ToList();

            _logger.LogInformation("Missing institutions count: {Count}", missingInstitutions.Count);

            if (missingInstitutions.Any())
            {
                await _context.Institutions.AddRangeAsync(missingInstitutions);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} missing institutions: {Institutions}", missingInstitutions.Count, string.Join(", ", missingInstitutions.Select(i => i.Name)));
            }
            else
            {
                _logger.LogInformation("All required institutions already exist.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedInstitutionsAsync");
            throw;
        }
    }

    private async Task SeedShowsAsync()
    {
        try
        {
            _logger.LogInformation("Starting SeedShowsAsync...");
            
            var dramaGenre = await _context.Genres.FirstOrDefaultAsync(g => g.Name == "Drama");
            var komedijaGenre = await _context.Genres.FirstOrDefaultAsync(g => g.Name == "Komedija");
            var djecjaGenre = await _context.Genres.FirstOrDefaultAsync(g => g.Name == "Dječija predstava");
            var baletGenre = await _context.Genres.FirstOrDefaultAsync(g => g.Name == "Balet");

            var npsInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Narodno pozorište Sarajevo");
            var ktInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Kamerni teatar 55");
            var sartrInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Sarajevski ratni teatar");
            var pozmInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Pozorište mladih Sarajevo");
            var bkcInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Bosanski kulturni centar");
            var dmInstitution = await _context.Institutions.FirstOrDefaultAsync(i => i.Name == "Dom mladih Skenderija");

            if (dramaGenre == null || npsInstitution == null)
            {
                _logger.LogWarning("Required genres or institutions not found. Please seed them first.");
                return;
            }

        var requiredShows = new[]
        {
            new
            {
                Title = "Sarajevo moje drago",
                Description = "\"Sarajevo moje drago\" je bosanskohercegovački mjuzikl koji će Narodno pozorište u Sarajevu svojoj publici premijerno predstaviti prvih dana ovogodišnje jesenje pozorišne sezone. Ovaj mjuzikl je autorsko djelo Zlatana Fazlića Fazle koji potpisuje libreto i 20 novih muzičkih kompozicija. Priča je originalna, a sve muzičke numere su nove, napravljene ciljano za ovo muzičko-scensko djelo. Aranžmane muzičkih numera napravio je maestro Ranko Rihtman koji će i dirigirati orkestrom Sarajevske filharmonije, a ovaj veliki i zahtjevni muzički i dramski komad režiraće Dino Mustafić. U mjuziklu \"Sarajevo moje drago\" sudjelovaće velika glumačka ekipa vrhunskih domaćih pozorišnih umjetnika, kao Balet i Hor opere Narodnog pozorišta u Sarajevu.",
                DurationMinutes = 90,
                Institution = npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/sarajevo-moje-drago.jpeg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3233333")
            },
            new
            {
                Title = "Marlene Dietrich - Pet tačaka optužnice",
                Description = "Marlene Dietrich je bila više od filmske zvijezde – bila je mit. Jedna veoma neobična žena, veoma posebna, koja je u svom životu uvijek pravila nekonvencionalne izbore, često rizikujući reakciju svoje okoline – bilo privatne, profesionalne ili reakciju u svojoj domovini.",
                DurationMinutes = 105,
                Institution = npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/marlene-dietrich-pet-tacaka-optuznice.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Na slovo F",
                Description = "\"Beznađe. Izgubljenost. Potraga za smislom. Vera u ljubav. Čežnja za srećom. Ovo su samo neke od tema o kojima nastojimo da progovorimo kroz predstavu. Nadam se da ćemo uspeti da ukažemo na neprikosnoveni značaj ljubavi, dobrote i razumevanja za drugog, kao i na zlo koje proističe iz predrasuda i okrutnosti.\" – zapisala je rediteljica Iva Milošević.",
                DurationMinutes = 110,
                Institution = npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/na-slovo-f.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Snjeguljica i sedam patuljaka",
                Description = "Kralj i kraljica dobiše kćerkicu, kože bijele kao snijeg, obraza rumenih kao krv, a kose crne kao gar. Prozvaše je Snjeguljica. Njihova sreća, nažalost nije dugo trajala, jer se kraljica uskoro razboli i umre, a kralj se oženi drugom ženom, koja je bila lijepa, ali ohola i zla. Nije podnosila da iko bude ljepši od nje, a imala je čarobno ogledalo koje joj je odgovaralo na pitanje: \"Ko je najljepši u zemlji?\". Dok je odgovor bio: \"Kraljice, Vi ste najljepši\", bila je zadovoljna, ali je živjela u strahu da se situacija ne promijeni.",
                DurationMinutes = 70,
                Institution = npsInstitution,
                Genre = baletGenre ?? dramaGenre,
                ImagePath = (string?)"/images/snjeguljica-i-sedam-patuljaka.jpeg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "ON(A)",
                Description = "Predstava ON(A) inspirisana je stvarnim životima bračnog para, danskih umjetnika Gerde i Einara Wegenera – kasnije Lili Elbe, transrodne žene i jedne od prvih osoba koja se podvrgnula operaciji promjene spola. Ovo je intimna i snažna priča o bezuslovnoj ljubavi, potrazi za identitetom i hrabrosti da upoznamo i prihvatimo sebe, bez obzira na cijenu koju ta istina nosi.",
                DurationMinutes = 90,
                Institution = ktInstitution ?? npsInstitution,
                Genre = dramaGenre,
                // Nema slike u projektu -> fallback na sliku institucije
                ImagePath = (string?)null,
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Malograđanska svadba",
                Description = "Svatovi jedu, piju, govore, plešu samo da ne bi nastala tišina koja je trenutak ozbiljne opasnosti, upravo zbog toga jer može postati trenutak razmišljanja i ujedno trenutak konfrontacije sa samim sobom. Samodestrukcija i opšti raspad je svakako posljedica malograđanskog odsustva tišine...",
                DurationMinutes = 90,
                Institution = ktInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/malogradjanska-svadba.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Otac",
                Description = "Cilj nam je da se u pozorištu progovori o društveno neprihvaćenim temama kao što su: suicid, razvod, mentalne bolesti, pozicija žene u porodici, dječija perspektiva na turbulentni svijet, starenje i smrt…",
                DurationMinutes = 90,
                Institution = ktInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/otac.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Ljubavnice",
                Description = "Prema romanu dobitnice Nobelove nagrade za književnost, Elfriede Jelinek, u režiji Jovane Tomić. Jedan od najvažnijih romana austrijske nobelovke Elfriede Jelinek stiže na našu scenu! \"Ljubavnice\" donose priču o ženama u patrijarhalnom društvu, njihovim borbama sa društvenim normama, ljubavlju i nemilosrdnim kapitalizmom. Brigita, Paula i Suzi vode vas u svijet gdje je sve rad, a ljubav – možda samo još jedan oblik teškog rada. Da li je moguće pronaći slobodu i smisao u svijetu koji sve podređuje profitu? Otkrijte odgovore u ovoj provokativnoj i emotivnoj predstavi koja će vas potaknuti na razmišljanje.",
                DurationMinutes = 90,
                Institution = ktInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/ljubavnice.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Totovi",
                Description = "Komad je groteska sa elementima satire, koji je Ištvan Erkenj, jedan od najpriznatijih mađarskih pisaca 20. veka napisao na osnovu novele \"Dobrodošlica za Majora\" iz 1966. godine. Inspirisana je stravičnom, istovremeno besmislenom i uzaludnom, sudbinom mađarskih vojnika na Istočnom frontu januara 1943.",
                DurationMinutes = 100,
                Institution = sartrInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/totovi.webp",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Za život cijeli",
                Description = "Sama činjenica da je \"Za život cijeli\" predstava o nogometnom klubu, o povijesti nogometa u gradu Sarajevu, o 103 godine historije grada Sarajeva i FK Željezničar čini je jedinstvenom u teatarskom životu BiH, regiona i svijeta.",
                DurationMinutes = 80,
                Institution = sartrInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/za-zivot-cijeli.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Njih više nema",
                Description = "Poslije više od četiri godine umjetničkog istraživačkog procesa, nastaje nova predstava koja koristeći hibridne teatarske forme ispituje pitanje odgovornosti, zaborava i solidarnosti. Ovaj komad preispituje poziciju svih nas u publici – kako razumijemo i odnosimo se prema onima koji su preživjeli genocid u Srebrenici.",
                DurationMinutes = 95,
                Institution = sartrInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/njih-vise-nema.webp",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Podroom",
                Description = "Predstava istražuje klimave temelje i mehanizme ljudskih odnosa u vremenu nesigurnosti, u kojem se intenzivni odnosi stvaraju i raspadaju u sve kraćim vremenskim razmacima.",
                DurationMinutes = 90,
                Institution = sartrInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/podroom.webp",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3266667")
            },
            new
            {
                Title = "Ne daj se generacijo",
                Description = "Radnja prati priču o dvije prijateljice koje su nerazdvojene dugi niz godina. Tekst u osnovici tretira temu prijateljstva. Svakodnevnica i preživljavanje uz stereotipne, nametnute forme osobama treće dobi. Želja za iskorakom, neprihvatanjem standardizovanih obrazaca junakinje ove priče odvodi na novo i nepoznato putovanje. Odbijanjem konvecionalnosti dolaze do iskustava koje ih mijenjaju i život čine uzbudljivijim. Upuštaju se u avanture koje im omogućavaju iznenađenja. Otkrivaju život za kakav su mislile da je iza njih.",
                DurationMinutes = 60,
                Institution = pozmInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/ne-daj-se-generacijo.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "Cvrčak i mrav",
                Description = "Ova izuzetno poučna basna godinama oplemenjuje mnoge pozorišne repertoare. Zbog svoje aktuelnosti i univerzalnosti našla je mjesto i na repertoaru našeg pozorišta. Pričao je to o prijateljstvu, igri, zabavi i radu u kojoj likovi Cvrčka i Mrava predstavljaju ravnotežu između duhovnih i materijalnih vrijednosti potrebnih svakom živom biću. Pjesme i snovi osnovni su motivi ove predstave u kojoj likovi sanjaju sunce, prirodu i ljeto, oni u stvari žele da budu veseli i sretni. Glavni junak ove priče Cvrčak svojom muzikom budi cvjetove i miri različite svjetove, njegova muzika postaje čarobna tajna i ljepota sjajna. Kroz lepršavu i razigranu igru na sceni, songove, živopisnu scenografiju i kostime Pozorište mladih ovom predstavom će sigurno zaintrigirati najmlađu publiku, zabaviti ih i educirati, a stariju publiku \"vratiti\" u djetinjstvo i sjetiti ih na vrijeme kad su bili djeca- Adis Bakrač",
                DurationMinutes = 60,
                Institution = pozmInstitution ?? npsInstitution,
                Genre = djecjaGenre ?? dramaGenre,
                // Napomena: file u wwwroot je "cvrcak-i-mrav.jpg"
                ImagePath = (string?)"/images/cvrcak-i-mrav.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "DOVIĐENJA",
                Description = "Tema odlaska mladih u potrazi za boljim životom izuzetno je relevantna za Bosnu i Hercegovinu, koja se već godinama suočava s problemom masovnih migracija. Predstava koristi univerzalni jezik teatra da ispriča priču koja pogađa mnoge porodice u našoj domovini, dok istovremeno povezuje lokalne probleme s globalnim izazovima kao što su klimatske promjene i društvena nestabilnost. Kroz inovativnu postavku i emotivno nabijenu priču, projekt ima potencijal, ne samo da privuče publiku, već i da pokrene šire diskusije o budućnosti mladih i održivosti naše planete",
                DurationMinutes = 60,
                Institution = pozmInstitution ?? npsInstitution,
                Genre = dramaGenre,
                ImagePath = (string?)"/images/dovidjenja.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "TAJNI DNEVNIK ADRIANA MOLEA",
                Description = "Tajni dnevnik Adriana Molea je predstava namjenjena teenagerima, ali još više odraslima. To je ispovjest pubertetlije, ali i kolektivno povjeravanje svih onih koji čine ovu priču i predstavu. Tajni dnevnik je glavni junak. Govori nam o važnosti samosvijesti i povjeravanja. O značaju i hrabrosti čina da budeš potpuno otvoren.",
                DurationMinutes = 90,
                Institution = pozmInstitution ?? npsInstitution,
                Genre = djecjaGenre ?? dramaGenre,
                ImagePath = (string?)"/images/tajni-dnevnik-adriana-molea.jpeg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "Patrolne šape",
                Description = "Predstava je rađena prema, trenutno najpopularnijoj crtanoj TV seriji \"Patrolne šape\". Puna je zapleta, uzbudljiva, edukativna, intraktivna, a govori o ljubavi, prijateljstvu, snalažljivosti, iskrenosti, borbi između dobra i zla, timskom radu i uzornom ponašanju.",
                DurationMinutes = 60,
                Institution = dmInstitution ?? npsInstitution,
                Genre = djecjaGenre ?? dramaGenre,
                ImagePath = (string?)"/images/patrolne-sape.jpg",
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            }
            ,
            new
            {
                Title = "LAJFKOUČ.ba",
                Description = "„Lajf Kouč“ je monodrama u kojoj Dragan Marinković Maca secira današnje društvo s brutalnom iskrenošću i humorom koji boli. Predstava razotkriva svijet u kojem su moral, poštenje i ljubav postali relikti prošlosti. Maca kroz lucidne monologe vodi publiku od smijeha do tišine, od ironije do samopreispitivanja. Predstava razotkriva apsurd civilizacije koja je zaboravila razgovarati, voljeti i saosjećati. Maca nas podsjeća da smo izgubili smisao života u jurnjavi za stvarima koje ne trebamo, dok zanemarujemo ljude koje volimo.",
                DurationMinutes = 60,
                Institution = bkcInstitution ?? npsInstitution,
                Genre = komedijaGenre ?? dramaGenre,
                // Nema slike u projektu -> fallback na sliku institucije
                ImagePath = (string?)null,
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "Labuđe jezero",
                Description = "Nakon 10 godina od kada su u Sarajevu pokazali balet „Labudovo jezero“ jedan je od najpoznatijih i najizvođenijih baleta u svijetu tokom 19. i 20. stoljeća, ponovno dolazi, a ovaj puta u izvedbi Ukrajinskog klasičnog baleta!„Labudovo jezero“ je jedan od rijetkih baleta koji je poznat gotovo svima, a ne samo strastvenim ljubiteljima baletske umjetnosti. Ovo djelo slavnog ruskog kompozitora Petra Iljiča Čajkovskog klasik je koji ne poznaje granice i koji je tokom 148 godina postojanja dokazao da je umjetnost most koji spaja nacije i kulture na svim meridijanima.",
                DurationMinutes = 120,
                Institution = bkcInstitution ?? npsInstitution,
                Genre = baletGenre ?? dramaGenre,
                ImagePath = (string?)null, // nema slike -> koristi sliku institucije (ili default)
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "Neprijateljice",
                Description = "Mia poziva svoje najbolje drugarice u stan u koji se tek uselila kako bi ih upoznala sa novim dečkom i proslavila početak svog novog života.",
                DurationMinutes = 60,
                Institution = dmInstitution ?? npsInstitution,
                Genre = komedijaGenre ?? dramaGenre,
                ImagePath = (string?)null, // nema slike -> koristi sliku institucije (ili default)
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            },
            new
            {
                Title = "PAS MATTER",
                Description = "Psi vode slijepe, spašavaju ranjene, pronalaze izgubljene, pružaju utjehu i donose radost. Mogu sve to – i još mnogo više. Ono što ne mogu jeste ispričati vlastite priče. A zaslužili su da ih neko ispriča.",
                DurationMinutes = 60,
                Institution = dmInstitution ?? npsInstitution,
                Genre = komedijaGenre ?? dramaGenre,
                // Nema slike u projektu -> fallback na sliku institucije
                ImagePath = (string?)null,
                CreatedAt = DateTime.Parse("2026-01-08T02:45:36.3300000")
            }
        };

            var existingShowTitles = await _context.Shows
                .Select(s => s.Title)
                .ToListAsync();

            _logger.LogInformation("Found {Count} existing shows: {Shows}", existingShowTitles.Count, string.Join(", ", existingShowTitles.Take(5)) + (existingShowTitles.Count > 5 ? "..." : ""));

            var missingShows = requiredShows
                .Where(s => !existingShowTitles.Contains(s.Title))
                .Select(s => new Show
                {
                    Title = s.Title,
                    Description = s.Description,
                    DurationMinutes = s.DurationMinutes,
                    InstitutionId = s.Institution.Id,
                    GenreId = s.Genre.Id,
                    ImagePath = s.ImagePath,
                    IsActive = true,
                    CreatedAt = s.CreatedAt
                })
                .ToList();

            _logger.LogInformation("Missing shows count: {Count}", missingShows.Count);

            if (missingShows.Any())
            {
                await _context.Shows.AddRangeAsync(missingShows);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} missing shows: {Shows}", missingShows.Count, string.Join(", ", missingShows.Select(s => s.Title)));
            }
            else
            {
                _logger.LogInformation("All required shows already exist.");
            }

            // Fix-up za postojeće predstave (ako su seedane ranije sa pogrešnim putanjama slika)
            var titlesToFix = new[] { "Cvrčak i mrav", "LAJFKOUČ.ba", "ON(A)", "PAS MATTER" };
            var toFix = await _context.Shows
                .Where(s => titlesToFix.Contains(s.Title))
                .ToListAsync();

            var fixedAny = false;
            foreach (var s in toFix)
            {
                if (s.Title == "Cvrčak i mrav" && string.Equals(s.ImagePath, "/images/cvrcek-i-mrav.jpg", StringComparison.OrdinalIgnoreCase))
                {
                    s.ImagePath = "/images/cvrcak-i-mrav.jpg";
                    fixedAny = true;
                }

                if ((s.Title == "LAJFKOUČ.ba" && string.Equals(s.ImagePath, "/images/lajfkouc-ba.png", StringComparison.OrdinalIgnoreCase)) ||
                    (s.Title == "ON(A)" && string.Equals(s.ImagePath, "/images/ona.jpg", StringComparison.OrdinalIgnoreCase)) ||
                    (s.Title == "PAS MATTER" && string.Equals(s.ImagePath, "/images/pas-matter.png", StringComparison.OrdinalIgnoreCase)))
                {
                    s.ImagePath = null;
                    fixedAny = true;
                }
            }

            if (fixedAny)
            {
                await _context.SaveChangesAsync();
                _logger.LogInformation("Applied show imagePath fix-ups for seeded data.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedShowsAsync");
            throw;
        }
    }


    private async Task SeedPerformancesAsync()
    {
        try
        {
            _logger.LogInformation("Starting SeedPerformancesAsync...");

            var shows = await _context.Shows
                .Include(s => s.Institution)
                .Where(s => s.IsActive)
                .ToListAsync();

            if (!shows.Any())
            {
                _logger.LogWarning("No shows found. Please seed shows first.");
                return;
            }

            var existingPerformanceKeys = (await _context.Performances
                    .Select(p => new { p.ShowId, p.StartTime })
                    .ToListAsync())
                .Select(p => (p.ShowId, p.StartTime))
                .ToHashSet();

            var performancesToAdd = new List<Performance>();

            bool PerformanceExists(int showId, DateTime startTime) =>
                existingPerformanceKeys.Contains((showId, startTime));

            void AddPerformanceIfNotExists(Show show, DateTime startTime, decimal price, int availableSeats)
            {
                if (!PerformanceExists(show.Id, startTime))
                {
                    performancesToAdd.Add(new Performance
                    {
                        ShowId = show.Id,
                        StartTime = startTime,
                        Price = price,
                        AvailableSeats = availableSeats,
                        CreatedAt = DateTime.UtcNow
                    });
                    existingPerformanceKeys.Add((show.Id, startTime));
                }
            }

            var nowUtc = DateTime.UtcNow;
            var year = nowUtc.Year;
            var fixedStart = new DateTime(year, 1, 10, 0, 0, 0, DateTimeKind.Unspecified);
            var fixedEnd = new DateTime(year, 2, 20, 0, 0, 0, DateTimeKind.Unspecified);
            if (nowUtc > fixedEnd.AddDays(2))
            {
                fixedStart = new DateTime(year + 1, 1, 10, 0, 0, 0, DateTimeKind.Unspecified);
                fixedEnd = new DateTime(year + 1, 2, 20, 0, 0, 0, DateTimeKind.Unspecified);
            }

            var prices = new[] { 10m, 12m, 15m, 20m, 25m, 40m };
            var rng = new Random(42);

            var showsByInstitution = shows
                .GroupBy(s => s.InstitutionId)
                .ToDictionary(g => g.Key, g => g.OrderBy(x => x.Title).Take(6).ToList());

            int SeatsFor(Show show)
            {
                var cap = show.Institution.Capacity;
                var sold = rng.Next(0, Math.Min(30, Math.Max(1, cap)));
                return Math.Max(1, cap - sold);
            }

            var dayCount = (fixedEnd.Date - fixedStart.Date).Days + 1;
            for (var dayOffset = 0; dayOffset < dayCount; dayOffset++)
            {
                if (dayOffset % 3 != 0) continue;

                var day = fixedStart.Date.AddDays(dayOffset);
                foreach (var kv in showsByInstitution)
                {
                    var instShows = kv.Value;
                    if (!instShows.Any()) continue;

                    var show = instShows[dayOffset % instShows.Count];
                    var start = DateTime.SpecifyKind(day.Add(new TimeSpan(19, 0, 0)), DateTimeKind.Unspecified);
                    var price = prices[rng.Next(prices.Length)];
                    AddPerformanceIfNotExists(show, start, price, SeatsFor(show));
                }
            }

            var endJanStart = new DateTime(fixedStart.Year, 1, 20, 0, 0, 0, DateTimeKind.Unspecified);
            var endJanEnd = new DateTime(fixedStart.Year, 1, 31, 0, 0, 0, DateTimeKind.Unspecified);
            for (var day = endJanStart.Date; day <= endJanEnd.Date; day = day.AddDays(2))
            {
                foreach (var kv in showsByInstitution)
                {
                    var instShows = kv.Value;
                    if (instShows.Count == 0) continue;

                    var slots = new[] { new TimeSpan(16, 0, 0), new TimeSpan(18, 0, 0), new TimeSpan(20, 0, 0) };
                    for (var i = 0; i < slots.Length; i++)
                    {
                        var show = instShows[(i + day.Day) % instShows.Count];
                        var start = DateTime.SpecifyKind(day.Add(slots[i]), DateTimeKind.Unspecified);
                        var price = prices[(i + day.Day) % prices.Length];
                        AddPerformanceIfNotExists(show, start, price, SeatsFor(show));
                    }
                }
            }

            var baseShow = shows.OrderBy(s => s.Title).First();
            var localNowApprox = DateTime.SpecifyKind(DateTime.UtcNow, DateTimeKind.Unspecified);
            AddPerformanceIfNotExists(baseShow, localNowApprox.AddMinutes(-10), 15m, Math.Max(1, baseShow.Institution.Capacity - 5)); // u toku
            AddPerformanceIfNotExists(baseShow, localNowApprox.AddMinutes(45), 15m, Math.Max(1, baseShow.Institution.Capacity - 12)); // sljedeća
            AddPerformanceIfNotExists(baseShow, localNowApprox.AddHours(-3), 15m, Math.Max(1, baseShow.Institution.Capacity - 25)); // završena

            _logger.LogInformation("Missing performances count: {Count}", performancesToAdd.Count);

            if (performancesToAdd.Any())
            {
                await _context.Performances.AddRangeAsync(performancesToAdd);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} missing performances.", performancesToAdd.Count);
            }
            else
            {
                _logger.LogInformation("All required performances already exist.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedPerformancesAsync");
            throw;
        }
    }

    private async Task SeedOrdersTicketsReviewsAsync()
    {
        try
        {
            _logger.LogInformation("Starting SeedOrdersTicketsReviewsAsync...");

            var seedUserEmails = new List<string>
            {
                "mobile@sapplauz.ba",
            };
            for (var i = 1; i <= 6; i++) seedUserEmails.Add($"korisnik{i}@sapplauz.ba");

            var seedUsers = await _userManager.Users
                .Where(u => seedUserEmails.Contains(u.Email!))
                .ToListAsync();

            if (!seedUsers.Any())
            {
                _logger.LogWarning("No seed users found for orders/tickets.");
                return;
            }

            var seedUserIds = seedUsers.Select(u => u.Id).ToList();
            var usersWithOrders = await _context.Orders
                .Where(o => seedUserIds.Contains(o.UserId))
                .Select(o => o.UserId)
                .Distinct()
                .ToListAsync();
            var usersWithOrdersSet = usersWithOrders.ToHashSet();

            var now = DateTime.UtcNow;
            var performances = await _context.Performances
                .Include(p => p.Show)
                    .ThenInclude(s => s.Institution)
                .ToListAsync();

            if (!performances.Any())
            {
                _logger.LogWarning("No performances found. Please seed performances first.");
                return;
            }

            DateTime GetEnd(Performance p) => p.StartTime.AddMinutes(p.Show.DurationMinutes);

            var ended = performances.Where(p => GetEnd(p) < now.AddMinutes(-30)).OrderByDescending(p => p.StartTime).ToList();
            var upcoming = performances.Where(p => p.StartTime > now.AddMinutes(30)).OrderBy(p => p.StartTime).ToList();
            var current = performances.Where(p => p.StartTime <= now && GetEnd(p) >= now).OrderBy(p => p.StartTime).ToList();

            if (!ended.Any()) ended = performances.OrderBy(p => p.StartTime).ToList();
            if (!upcoming.Any()) upcoming = performances.OrderByDescending(p => p.StartTime).ToList();

            var rng = new Random(77);

            string NewQr() => $"SAPPLAUZ-{Guid.NewGuid():N}";

            var institutionIds = performances.Select(p => p.Show.InstitutionId).Distinct().OrderBy(x => x).ToList();
            if (institutionIds.Count == 0) institutionIds = new List<int> { 1 };

            List<Performance> EndedFor(int instId) =>
                ended.Where(p => p.Show.InstitutionId == instId).ToList();
            List<Performance> UpcomingFor(int instId) =>
                upcoming.Where(p => p.Show.InstitutionId == instId).ToList();

            foreach (var u in seedUsers)
            {
                if (usersWithOrdersSet.Contains(u.Id))
                {
                    continue;
                }

                var baseIdx = Math.Abs(u.Email?.GetHashCode() ?? 0) % institutionIds.Count;
                var instA = institutionIds[baseIdx];
                var instB = institutionIds[(baseIdx + 1) % institutionIds.Count];
                var instC = institutionIds[(baseIdx + 2) % institutionIds.Count];

                var endedA = EndedFor(instA);
                var upcomingB = UpcomingFor(instB);
                var upcomingC = UpcomingFor(instC);

                if (!endedA.Any()) endedA = ended;
                if (!upcomingB.Any()) upcomingB = upcoming;
                if (!upcomingC.Any()) upcomingC = upcoming;

                var pEnded = endedA[rng.Next(Math.Min(endedA.Count, 50))];
                await CreateOrderWithTicketsAsync(
                    userId: u.Id,
                    performance: pEnded,
                    status: OrderStatus.Paid,
                    quantity: rng.Next(1, 4),
                    ticketStatus: TicketStatus.Scanned,
                    scannedAt: pEnded.StartTime.AddMinutes(10),
                    createdAt: pEnded.StartTime.AddDays(-2));

                var pNext = upcomingB[rng.Next(Math.Min(upcomingB.Count, 50))];
                await CreateOrderWithTicketsAsync(
                    userId: u.Id,
                    performance: pNext,
                    status: OrderStatus.Paid,
                    quantity: rng.Next(1, 3),
                    ticketStatus: TicketStatus.NotScanned,
                    scannedAt: null,
                    createdAt: pNext.StartTime.AddDays(-1));

                var pPending = upcomingC[rng.Next(Math.Min(upcomingC.Count, 50))];
                await CreateOrderWithTicketsAsync(
                    userId: u.Id,
                    performance: pPending,
                    status: OrderStatus.Pending,
                    quantity: 1,
                    ticketStatus: TicketStatus.NotScanned,
                    scannedAt: null,
                    createdAt: now.AddDays(-rng.Next(1, 10)));

                var pRefunded = endedA[rng.Next(Math.Min(endedA.Count, 50))];
                await CreateOrderWithTicketsAsync(
                    userId: u.Id,
                    performance: pRefunded,
                    status: OrderStatus.Refunded,
                    quantity: 1,
                    ticketStatus: TicketStatus.Refunded,
                    scannedAt: null,
                    createdAt: pRefunded.StartTime.AddDays(-3));

                var pExpired = endedA[rng.Next(Math.Min(endedA.Count, 50))];
                await CreateOrderWithTicketsAsync(
                    userId: u.Id,
                    performance: pExpired,
                    status: OrderStatus.Paid,
                    quantity: 1,
                    ticketStatus: TicketStatus.NotScanned,
                    scannedAt: null,
                    createdAt: pExpired.StartTime.AddDays(-4));
            }

            var nowInAppTz = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, GetAppTimeZone());
            var scannedTickets = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Performance)
                        .ThenInclude(p => p.Show)
                .Where(t =>
                    seedUsers.Select(u => u.Id).Contains(t.OrderItem.Order.UserId) &&
                    t.OrderItem.Order.Status == OrderStatus.Paid &&
                    t.Status == TicketStatus.Scanned)
                .ToListAsync();

            var eligibleShowIdsByUser = scannedTickets
                .Where(t =>
                {
                    var dur = t.OrderItem.Performance.Show.DurationMinutes > 0 ? t.OrderItem.Performance.Show.DurationMinutes : 90;
                    return t.OrderItem.Performance.StartTime.AddMinutes(dur) < nowInAppTz;
                })
                .GroupBy(t => t.OrderItem.Order.UserId)
                .ToDictionary(
                    g => g.Key,
                    g => g.Select(t => t.OrderItem.Performance.ShowId).Distinct().ToList()
                );

            var existingReviews = await _context.Reviews
                .Where(r => seedUsers.Select(u => u.Id).Contains(r.UserId))
                .Select(r => new { r.UserId, r.ShowId })
                .ToListAsync();
            var existingReviewKeys = existingReviews.Select(x => (x.UserId, x.ShowId)).ToHashSet();

            var reviewsToAdd = new List<Review>();
            foreach (var u in seedUsers)
            {
                if (!eligibleShowIdsByUser.TryGetValue(u.Id, out var showIds) || showIds.Count == 0)
                {
                    continue;
                }

                foreach (var showId in showIds.Take(3))
                {
                    var key = (u.Id, showId);
                    if (existingReviewKeys.Contains(key)) continue;
                    existingReviewKeys.Add(key);

                    reviewsToAdd.Add(new Review
                    {
                        UserId = u.Id,
                        ShowId = showId,
                        Rating = rng.Next(3, 6),
                        Comment = $"Odlična predstava! (seed korisnik: {u.FirstName} {u.LastName})",
                        IsVisible = true,
                        CreatedAt = DateTime.UtcNow.AddDays(-rng.Next(1, 25))
                    });
                }
            }

            var anyEligible = eligibleShowIdsByUser.FirstOrDefault(kv => kv.Value.Count > 0);
            if (!string.IsNullOrWhiteSpace(anyEligible.Key) && anyEligible.Value.Count > 0)
            {
                var u0 = seedUsers.First();
                var show0 = anyEligible.Value.First();
                var key0 = (u0.Id, show0);
                if (!existingReviewKeys.Contains(key0))
                {
                    reviewsToAdd.Add(new Review
                    {
                        UserId = u0.Id,
                        ShowId = show0,
                        Rating = 2,
                        Comment = "Ovo je test nevidljiva recenzija (moderacija).",
                        IsVisible = false,
                        CreatedAt = DateTime.UtcNow.AddDays(-3)
                    });
                }
            }

            if (reviewsToAdd.Any())
            {
                await _context.Reviews.AddRangeAsync(reviewsToAdd);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} reviews.", reviewsToAdd.Count);
            }

            var existingProfiles = await _context.RecommendationProfiles
                .Where(p => seedUsers.Select(u => u.Id).Contains(p.UserId))
                .ToListAsync();
            var existingProfileUserIds = existingProfiles.Select(p => p.UserId).ToHashSet();

            var profilesToAdd = new List<RecommendationProfile>();
            foreach (var u in seedUsers)
            {
                if (existingProfileUserIds.Contains(u.Id)) continue;

                var genres = scannedTickets
                    .Where(t => t.OrderItem.Order.UserId == u.Id)
                    .Select(t => t.OrderItem.Performance.Show.GenreId)
                    .Distinct()
                    .ToList();

                var prefs = new Dictionary<int, double>();
                foreach (var g in genres)
                {
                    prefs[g] = prefs.TryGetValue(g, out var v) ? v + 1.0 : 1.0;
                }

                profilesToAdd.Add(new RecommendationProfile
                {
                    UserId = u.Id,
                    PreferredGenresJson = prefs.Count == 0 ? null : JsonSerializer.Serialize(prefs),
                    LastUpdated = DateTime.UtcNow
                });
            }

            if (profilesToAdd.Any())
            {
                await _context.RecommendationProfiles.AddRangeAsync(profilesToAdd);
                await _context.SaveChangesAsync();
                _logger.LogInformation("Seeded {Count} recommendation profiles.", profilesToAdd.Count);
            }

            _logger.LogInformation("SeedOrdersTicketsReviewsAsync completed.");

            async Task CreateOrderWithTicketsAsync(
                string userId,
                Performance performance,
                OrderStatus status,
                int quantity,
                TicketStatus ticketStatus,
                DateTime? scannedAt,
                DateTime createdAt)
            {
                var order = new Order
                {
                    UserId = userId,
                    InstitutionId = performance.Show.InstitutionId,
                    Status = status,
                    CreatedAt = DateTime.SpecifyKind(createdAt, DateTimeKind.Utc),
                    UpdatedAt = DateTime.UtcNow
                };

                var oi = new OrderItem
                {
                    PerformanceId = performance.Id,
                    Quantity = quantity,
                    UnitPrice = performance.Price
                };

                for (var i = 0; i < quantity; i++)
                {
                    oi.Tickets.Add(new Ticket
                    {
                        QRCode = NewQr(),
                        Status = ticketStatus,
                        ScannedAt = scannedAt,
                        CreatedAt = DateTime.UtcNow
                    });
                }

                order.OrderItems.Add(oi);
                order.TotalAmount = quantity * performance.Price;

                _context.Orders.Add(order);

                if (status == OrderStatus.Paid)
                {
                    order.Payments.Add(new Payment
                    {
                        Amount = order.TotalAmount,
                        Status = PaymentStatus.Succeeded,
                        StripePaymentIntentId = $"pi_seed_{Guid.NewGuid():N}",
                        CreatedAt = DateTime.UtcNow
                    });
                }
                else if (status == OrderStatus.Refunded)
                {
                    order.Payments.Add(new Payment
                    {
                        Amount = order.TotalAmount,
                        Status = PaymentStatus.Refunded,
                        StripePaymentIntentId = $"pi_seed_{Guid.NewGuid():N}",
                        CreatedAt = DateTime.UtcNow
                    });
                }
            
                if (status == OrderStatus.Paid)
                {
                    performance.AvailableSeats = Math.Max(0, performance.AvailableSeats - quantity);
                    performance.UpdatedAt = DateTime.UtcNow;
                }

                await _context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SeedOrdersTicketsReviewsAsync");
            throw;
        }
    }

    private static TimeZoneInfo GetAppTimeZone()
    {
        try { return TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo"); } catch { /* ignore */ }
        try { return TimeZoneInfo.FindSystemTimeZoneById("Central European Standard Time"); } catch { /* ignore */ }
        return TimeZoneInfo.Local;
    }
}

