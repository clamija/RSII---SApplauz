using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace SApplauz.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ImagesController : ControllerBase
{
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<ImagesController> _logger;

    private const long MaxBytes = 10 * 1024 * 1024;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".webp"
    };

    public ImagesController(IWebHostEnvironment env, ILogger<ImagesController> logger)
    {
        _env = env;
        _logger = logger;
    }

    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxBytes)]
    public async Task<IActionResult> Upload([FromForm] UploadImageRequest request)
    {
        try
        {
            var file = request.File;
            var folder = request.Folder;

            if (file == null || file.Length == 0)
            {
                return BadRequest(new { message = "Slika nije poslana." });
            }

            if (file.Length > MaxBytes)
            {
                return BadRequest(new { message = "Slika je prevelika. Maksimalno 10MB." });
            }

            var ext = Path.GetExtension(file.FileName);
            if (string.IsNullOrWhiteSpace(ext) || !AllowedExtensions.Contains(ext))
            {
                return BadRequest(new { message = "Nepodržan format slike. Dozvoljeno: jpg, jpeg, png, webp." });
            }

            var safeFolder = SanitizeFolder(folder);

            var imagesRoot = Path.Combine(_env.WebRootPath, "images", safeFolder);
            Directory.CreateDirectory(imagesRoot);

            var fileName = $"{Guid.NewGuid():N}{ext.ToLowerInvariant()}";
            var fullPath = Path.Combine(imagesRoot, fileName);

            await using (var stream = System.IO.File.Create(fullPath))
            {
                await file.CopyToAsync(stream);
            }

            var relativePath = $"/images/{safeFolder}/{fileName}";
            return Ok(new { path = relativePath });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Greška pri upload-u slike");
            return StatusCode(500, new { message = "Greška pri upload-u slike." });
        }
    }

    public sealed class UploadImageRequest
    {
        public IFormFile File { get; set; } = default!;
        public string? Folder { get; set; }
    }

    private static string SanitizeFolder(string? folder)
    {
        if (string.IsNullOrWhiteSpace(folder)) return "misc";
        var f = folder.Trim().ToLowerInvariant();
    
        return f switch
        {
            "shows" => "shows",
            "institutions" => "institutions",
            _ => "misc"
        };
    }
}

