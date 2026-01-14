using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using SApplauz.Application.Interfaces;
using SApplauz.Domain.Entities;
using SApplauz.Infrastructure.Identity;
using SApplauz.Shared.DTOs;
using System.Text.Json;

namespace SApplauz.Application.Services;

/// <summary>
/// Servis za generisanje personalizovanih preporuka predstava korisnicima.
/// Koristi content-based filtering algoritam baziran na žanrovima predstava i korisničkim preferencijama.
/// </summary>
public class RecommendationService : IRecommendationService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IMapper _mapper;
    private readonly IMemoryCache _cache;
    private const int CacheExpirationMinutes = 60; // 1 sat

    /// <summary>
    /// Inicijalizuje novu instancu RecommendationService.
    /// </summary>
    /// <param name="dbContext">Database context za pristup podacima</param>
    /// <param name="mapper">AutoMapper za mapiranje entiteta u DTO-ove</param>
    /// <param name="cache">Memory cache za keširanje preporuka (opcionalno)</param>
    public RecommendationService(ApplicationDbContext dbContext, IMapper mapper, IMemoryCache? cache = null)
    {
        _dbContext = dbContext;
        _mapper = mapper;
        _cache = cache ?? new MemoryCache(new MemoryCacheOptions());
    }

    /// <summary>
    /// Generiše personalizovane preporuke predstava za određenog korisnika.
    /// Ako korisnik nema historiju (cold start), vraća popularne predstave.
    /// </summary>
    /// <param name="userId">ID korisnika za kojeg se generišu preporuke</param>
    /// <param name="count">Broj preporuka koje treba vratiti (default: 10, max: 50)</param>
    /// <returns>Lista preporuka sortirana po score-u (descending)</returns>
    public async Task<List<RecommendationDto>> GetRecommendationsAsync(string userId, int count = 10)
    {
        // Cache key po UserId i count
        var cacheKey = $"recommendations_{userId}_{count}";
        
        // Provjeri cache
        if (_cache.TryGetValue(cacheKey, out List<RecommendationDto>? cachedRecommendations) && cachedRecommendations != null)
        {
            return cachedRecommendations;
        }

        // Učitaj korisničke preferencije
        var userPreferences = await GetUserPreferencesAsync(userId);

        // Ako korisnik nema preferencija, vrati popularne predstave
        if (userPreferences.Count == 0)
        {
            var popularShows = await GetPopularShowsAsync(count);
            
            // Cache popularne predstave
            var cacheOptions = new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(CacheExpirationMinutes)
            };
            _cache.Set(cacheKey, popularShows, cacheOptions);
            
            return popularShows;
        }

        // Učitaj sve aktivne predstave sa žanrovima
        var allShows = await _dbContext.Shows
            .Include(s => s.Genre)
            .Include(s => s.Institution)
            .Include(s => s.Reviews)
            .Where(s => s.IsActive)
            .ToListAsync();

        // Učitaj predstave koje korisnik već ima (kupljene karte ili recenzije)
        var userShowIds = await GetUserShowIdsAsync(userId);

        // Izračunaj score za svaku predstavu
        var scoredShows = allShows
            .Where(s => !userShowIds.Contains(s.Id)) // Isključi predstave koje korisnik već ima
            .Select(show =>
            {
                var showGenres = new List<int> { show.GenreId };
                var score = CalculateScore(userPreferences, showGenres, show);
                return new { Show = show, Score = score };
            })
            .Where(x => x.Score > 0) // Samo predstave sa pozitivnim score-om
            .OrderByDescending(x => x.Score)
            .Take(count)
            .ToList();

        // Mapiraj u DTO-ove
        var recommendations = new List<RecommendationDto>();
        foreach (var item in scoredShows)
        {
            var show = item.Show;
            var showDto = _mapper.Map<ShowDto>(show);
            showDto.InstitutionName = show.Institution.Name;
            showDto.GenreId = show.GenreId;
            showDto.GenreName = show.Genre.Name;
            
            if (show.Reviews.Any())
            {
                showDto.AverageRating = show.Reviews.Average(r => r.Rating);
                showDto.ReviewsCount = show.Reviews.Count;
            }
            
            showDto.PerformancesCount = show.Performances.Count;
            
            var reason = GenerateReason(userPreferences, new List<string> { show.Genre.Name }, item.Score);
            
            recommendations.Add(new RecommendationDto
            {
                Show = showDto,
                Score = item.Score,
                Reason = reason
            });
        }

        // Cache recommendations
        var cacheOptions2 = new MemoryCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(CacheExpirationMinutes)
        };
        _cache.Set(cacheKey, recommendations, cacheOptions2);

        return recommendations;
    }

    /// <summary>
    /// Ažurira korisničke preferencije na osnovu kupljene karte ili recenzije.
    /// Dodaje žanr predstave u preferencije sa težinom baziranom na rating-u.
    /// </summary>
    /// <param name="userId">ID korisnika čije se preferencije ažuriraju</param>
    /// <param name="showId">ID predstave koja se dodaje u preferencije</param>
    /// <param name="rating">Ocjena predstave (1-5). Ako nije navedena, koristi se default težina 1.0</param>
    /// <returns>Task koji predstavlja asinhronu operaciju</returns>
    public async Task UpdateUserPreferencesAsync(string userId, int showId, int? rating = null)
    {
        // Učitaj predstavu sa žanrom
        var show = await _dbContext.Shows
            .Include(s => s.Genre)
            .FirstOrDefaultAsync(s => s.Id == showId);

        if (show == null)
        {
            return; // Show ne postoji, ignoriraj
        }

        // Učitaj ili kreiraj recommendation profile
        var profile = await _dbContext.RecommendationProfiles
            .FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null)
        {
            profile = new RecommendationProfile
            {
                UserId = userId,
                LastUpdated = DateTime.UtcNow
            };
            _dbContext.RecommendationProfiles.Add(profile);
        }

        // Učitaj trenutne preferencije
        var preferences = await GetUserPreferencesAsync(userId);

        // Dodaj žanr ove predstave u preferencije
        var genreId = show.GenreId;
        var weight = rating.HasValue ? rating.Value / 5.0 : 1.0; // Rating 1-5, normalizuj na 0-1

        if (preferences.ContainsKey(genreId))
        {
            preferences[genreId] += weight; // Povećaj težinu
        }
        else
        {
            preferences[genreId] = weight; // Dodaj novi žanr
        }

        // Normalizuj preferencije (opcionalno, da ne rastu previše)
        var maxPreference = preferences.Values.Max();
        if (maxPreference > 10)
        {
            var normalizationFactor = 10.0 / maxPreference;
            foreach (var key in preferences.Keys.ToList())
            {
                preferences[key] *= normalizationFactor;
            }
        }

        // Sačuvaj preferencije kao JSON
        var preferencesJson = JsonSerializer.Serialize(preferences);
        profile.PreferredGenresJson = preferencesJson;
        profile.LastUpdated = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();
    }

    /// <summary>
    /// Učitava korisničke preferencije iz baze podataka.
    /// Preferencije su čuvane kao JSON string u RecommendationProfile entitetu.
    /// </summary>
    /// <param name="userId">ID korisnika čije se preferencije učitavaju</param>
    /// <returns>Dictionary gdje je key GenreId, a value je težina preferencije (0-10)</returns>
    private async Task<Dictionary<int, double>> GetUserPreferencesAsync(string userId)
    {
        var profile = await _dbContext.RecommendationProfiles
            .FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null || string.IsNullOrEmpty(profile.PreferredGenresJson))
        {
            return new Dictionary<int, double>();
        }

        try
        {
            var preferences = JsonSerializer.Deserialize<Dictionary<int, double>>(profile.PreferredGenresJson);
            return preferences ?? new Dictionary<int, double>();
        }
        catch
        {
            return new Dictionary<int, double>();
        }
    }

    /// <summary>
    /// Pronalazi ID-eve predstava koje korisnik već ima (kupljene karte ili recenzije).
    /// Ove predstave se isključuju iz preporuka.
    /// </summary>
    /// <param name="userId">ID korisnika</param>
    /// <returns>Lista ID-eva predstava koje korisnik već ima</returns>
    private async Task<List<int>> GetUserShowIdsAsync(string userId)
    {
        // Predstave koje korisnik već ima (kupljene karte - Paid status)
        var purchasedShowIds = await _dbContext.Orders
            .Where(o => o.UserId == userId && o.Status == Domain.Entities.OrderStatus.Paid)
            .SelectMany(o => o.OrderItems)
            .Select(oi => oi.Performance.ShowId)
            .Distinct()
            .ToListAsync();

        // Predstave koje korisnik već recenzirao
        var reviewedShowIds = await _dbContext.Reviews
            .Where(r => r.UserId == userId)
            .Select(r => r.ShowId)
            .Distinct()
            .ToListAsync();

        return purchasedShowIds.Union(reviewedShowIds).Distinct().ToList();
    }

    /// <summary>
    /// Izračunava score preporuke za predstavu na osnovu korisničkih preferencija.
    /// Score se izračunava kao kombinacija:
    /// - Base score (50%): Preklapanje žanrova sa korisničkim preferencijama
    /// - Genre match bonus (30%): Proporcija matching žanrova
    /// - Rating bonus (20%): Prosječna ocjena predstave
    /// </summary>
    /// <param name="userPreferences">Korisničke preferencije (GenreId -> Weight)</param>
    /// <param name="showGenres">Lista ID-eva žanrova predstave</param>
    /// <param name="show">Predstava za koju se izračunava score</param>
    /// <returns>Score između 0.0 i 1.0 (1.0 = najbolja preporuka)</returns>
    private double CalculateScore(Dictionary<int, double> userPreferences, List<int> showGenres, Show show)
    {
        if (showGenres.Count == 0)
        {
            return 0;
        }

        // Izračunaj preklapanje žanrova
        double totalScore = 0;
        int matchingGenres = 0;

        foreach (var genreId in showGenres)
        {
            if (userPreferences.ContainsKey(genreId))
            {
                totalScore += userPreferences[genreId];
                matchingGenres++;
            }
        }

        if (matchingGenres == 0)
        {
            return 0;
        }

        // Normalizuj score (0-1)
        var baseScore = totalScore / (userPreferences.Values.Sum() + 1);
        
        // Dodaj bonus za broj matching žanrova
        var genreMatchBonus = (double)matchingGenres / showGenres.Count;
        
        // Dodaj bonus za prosječnu ocjenu (ako ima recenzije)
        var avgRating = show.Reviews.Any() 
            ? show.Reviews.Average(r => r.Rating) / 5.0 
            : 0.5; // Default 0.5 ako nema recenzija
        
        var ratingBonus = avgRating * 0.2; // 20% uticaj ocjene

        var finalScore = (baseScore * 0.5) + (genreMatchBonus * 0.3) + (ratingBonus * 0.2);
        
        return Math.Min(1.0, finalScore); // Ograniči na maksimum 1.0
    }

    /// <summary>
    /// Generiše ljudski-čitljiv razlog za preporuku na osnovu score-a i žanrova.
    /// </summary>
    /// <param name="userPreferences">Korisničke preferencije (ne koristi se direktno, ali može se proširiti)</param>
    /// <param name="showGenres">Lista naziva žanrova predstave</param>
    /// <param name="score">Izračunati score preporuke (0.0 - 1.0)</param>
    /// <returns>Tekstualni razlog za preporuku</returns>
    private string GenerateReason(Dictionary<int, double> userPreferences, List<string> showGenres, double score)
    {
        if (showGenres.Any())
        {
            if (score > 0.7)
            {
                return $"Visoko preporučujemo! Žanrovi: {string.Join(", ", showGenres)}";
            }

            if (score > 0.4)
            {
                return $"Preporučujemo na osnovu žanrova: {string.Join(", ", showGenres)}";
            }
        }

        if (score > 0.3)
        {
            return "Možda će vam se svidjeti";
        }

        return "Preporučujemo";
    }

    /// <summary>
    /// Vraća popularne predstave za cold start scenarije.
    /// Popularne predstave se sortiraju po broju recenzija i prosječnoj ocjeni.
    /// </summary>
    /// <param name="count">Broj popularnih predstava koje treba vratiti</param>
    /// <returns>Lista popularnih predstava sa default score-om 0.5</returns>
    private async Task<List<RecommendationDto>> GetPopularShowsAsync(int count)
    {
        // Vrati popularne predstave (najviše ocjene, najviše recenzija)
        var popularShows = await _dbContext.Shows
            .Include(s => s.Genre)
            .Include(s => s.Institution)
            .Include(s => s.Reviews)
            .Where(s => s.IsActive)
            .OrderByDescending(s => s.Reviews.Count)
            .ThenByDescending(s => s.Reviews.Any() ? s.Reviews.Average(r => r.Rating) : 0)
            .Take(count)
            .ToListAsync();

        var popularRecommendations = new List<RecommendationDto>();
        foreach (var show in popularShows)
        {
            var showDto = _mapper.Map<ShowDto>(show);
            showDto.InstitutionName = show.Institution.Name;
            showDto.GenreId = show.GenreId;
            showDto.GenreName = show.Genre.Name;
            
            if (show.Reviews.Any())
            {
                showDto.AverageRating = show.Reviews.Average(r => r.Rating);
                showDto.ReviewsCount = show.Reviews.Count;
            }
            
            showDto.PerformancesCount = show.Performances.Count;
            
            popularRecommendations.Add(new RecommendationDto
            {
                Show = showDto,
                Score = 0.5, // Default score za popularne
                Reason = "Popularna predstava"
            });
        }
        
        return popularRecommendations;
    }

    /// <summary>
    /// Invalidira cache preporuka za određenog korisnika.
    /// Poziva se nakon kupovine karte ili ostavljene recenzije.
    /// </summary>
    /// <param name="userId">ID korisnika čiji se cache invalidira</param>
    /// <returns>Task koji predstavlja asinhronu operaciju</returns>
    public Task InvalidateUserCacheAsync(string userId)
    {
        // Invalidiramo sve cache key-eve za ovog korisnika
        // Cache key format: "recommendations_{userId}_{count}"
        // Možemo invalidirati sve po pattern-u ili jednostavno sve varijacije count-a
        
        // Za sada, invalidirajmo najčešće count varijante (5, 10, 20)
        var commonCounts = new[] { 5, 10, 20, 50 };
        foreach (var count in commonCounts)
        {
            var cacheKey = $"recommendations_{userId}_{count}";
            _cache.Remove(cacheKey);
        }
        
        // Također možemo invalidirati sve key-eve koji počinju sa userId
        // Međutim, IMemoryCache ne podržava pattern-based invalidation direktno
        // Ovo je jednostavno rješenje koje pokriva najčešće slučajeve
        
        return Task.CompletedTask;
    }
}

