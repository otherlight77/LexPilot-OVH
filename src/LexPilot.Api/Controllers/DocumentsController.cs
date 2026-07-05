using LexPilot.Domain.Documents;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/documents")]
public class DocumentsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;

    public DocumentsController(AppDbContext db, IWebHostEnvironment env)
    {
        _db = db;
        _env = env;
    }

    [HttpGet]
    public async Task<IActionResult> GetDocuments([FromQuery] Guid? dossierId = null)
    {
        var query = _db.Documents
            .Include(x => x.Dossier)
            .Where(x => !x.IsArchived);

        if (dossierId.HasValue)
            query = query.Where(x => x.DossierId == dossierId.Value);

        var documents = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(200)
            .Select(x => new
            {
                x.Id,
                x.DossierId,
                x.FileName,
                x.OriginalFileName,
                x.ContentType,
                x.SizeBytes,
                x.Category,
                x.Notes,
                x.CreatedAtUtc
            })
            .ToListAsync();

        return Ok(documents);
    }

    [HttpPost("metadata")]
    public async Task<IActionResult> CreateDocumentMetadata(Document document)
    {
        var dossierExists = await _db.Dossiers.AnyAsync(x => x.Id == document.DossierId && !x.IsArchived);
        if (!dossierExists) return BadRequest("Dossier introuvable.");

        document.Id = Guid.NewGuid();
        document.CreatedAtUtc = DateTime.UtcNow;

        _db.Documents.Add(document);
        await _db.SaveChangesAsync();

        return Ok(document);
    }

    [HttpPost("upload/{dossierId:guid}")]
    public async Task<IActionResult> Upload(Guid dossierId, IFormFile file, [FromForm] string? category = null)
    {
        var dossierExists = await _db.Dossiers.AnyAsync(x => x.Id == dossierId && !x.IsArchived);
        if (!dossierExists) return BadRequest("Dossier introuvable.");
        if (file.Length == 0) return BadRequest("Fichier vide.");

        var uploadsRoot = Path.Combine(_env.ContentRootPath, "uploads", dossierId.ToString());
        Directory.CreateDirectory(uploadsRoot);

        var storedName = $"{Guid.NewGuid()}_{file.FileName}";
        var path = Path.Combine(uploadsRoot, storedName);

        await using (var stream = System.IO.File.Create(path))
        {
            await file.CopyToAsync(stream);
        }

        var document = new Document
        {
            DossierId = dossierId,
            FileName = storedName,
            OriginalFileName = file.FileName,
            ContentType = file.ContentType,
            StoragePath = path,
            SizeBytes = file.Length,
            Category = category,
            CreatedAtUtc = DateTime.UtcNow
        };

        _db.Documents.Add(document);
        await _db.SaveChangesAsync();

        return Ok(document);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Archive(Guid id)
    {
        var doc = await _db.Documents.FindAsync(id);
        if (doc == null) return NotFound();

        doc.IsArchived = true;
        await _db.SaveChangesAsync();

        return NoContent();
    }
}
