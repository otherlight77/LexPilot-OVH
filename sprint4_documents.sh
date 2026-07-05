#!/bin/bash
set -e

cd /opt/lexpilot-ovh

mkdir -p src/LexPilot.Domain/Documents

cat > src/LexPilot.Domain/Documents/Document.cs <<'CS'
using LexPilot.Domain.Dossiers;

namespace LexPilot.Domain.Documents;

public class Document
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid DossierId { get; set; }
    public Dossier? Dossier { get; set; }

    public string FileName { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public string StoragePath { get; set; } = string.Empty;
    public long SizeBytes { get; set; }

    public string? Category { get; set; }
    public string? Notes { get; set; }

    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsArchived { get; set; }
}
CS

cat > src/LexPilot.Infrastructure/Data/AppDbContext.cs <<'CS'
using LexPilot.Domain.Clients;
using LexPilot.Domain.Dossiers;
using LexPilot.Domain.Documents;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) {}

    public DbSet<Client> Clients => Set<Client>();
    public DbSet<Dossier> Dossiers => Set<Dossier>();
    public DbSet<Document> Documents => Set<Document>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Client>(entity =>
        {
            entity.ToTable("clients");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FirstName).HasMaxLength(150).IsRequired();
            entity.Property(x => x.LastName).HasMaxLength(150).IsRequired();
            entity.Property(x => x.CompanyName).HasMaxLength(200);
            entity.Property(x => x.Email).HasMaxLength(250);
            entity.Property(x => x.Phone).HasMaxLength(50);
            entity.Property(x => x.City).HasMaxLength(120);
            entity.Property(x => x.PostalCode).HasMaxLength(30);
        });

        modelBuilder.Entity<Dossier>(entity =>
        {
            entity.ToTable("dossiers");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Numero).HasMaxLength(80).IsRequired();
            entity.Property(x => x.Titre).HasMaxLength(250).IsRequired();
            entity.Property(x => x.TypeAffaire).HasMaxLength(120);
            entity.Property(x => x.Statut).HasMaxLength(80);
            entity.Property(x => x.Juridiction).HasMaxLength(200);
            entity.HasOne(x => x.Client)
                .WithMany()
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Document>(entity =>
        {
            entity.ToTable("documents");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FileName).HasMaxLength(260).IsRequired();
            entity.Property(x => x.OriginalFileName).HasMaxLength(260).IsRequired();
            entity.Property(x => x.ContentType).HasMaxLength(120);
            entity.Property(x => x.StoragePath).HasMaxLength(500).IsRequired();
            entity.Property(x => x.Category).HasMaxLength(120);
            entity.HasOne(x => x.Dossier)
                .WithMany()
                .HasForeignKey(x => x.DossierId)
                .OnDelete(DeleteBehavior.Restrict);
        });
    }
}
CS

cat > src/LexPilot.Api/Controllers/DocumentsController.cs <<'CS'
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
CS

python3 - <<'PY'
from pathlib import Path
p=Path("src/LexPilot.Api/Program.cs")
s=p.read_text()
s=s.replace('version = "0.3.0"', 'version = "0.4.0"')
s=s.replace('documents = 0,', 'documents = await db.Documents.CountAsync(x => !x.IsArchived),')
s=s.replace('message = "Sprint 3 Dossiers actif"', 'message = "Sprint 4 Documents actif"')
p.write_text(s)
PY

dotnet build

pkill -f "LexPilot.Api" || true
nohup dotnet run --project src/LexPilot.Api/LexPilot.Api.csproj --urls http://0.0.0.0:5128 > lexpilot.log 2>&1 &

sleep 7

echo "HEALTH:"
curl http://localhost:5128/health
echo ""

DOSSIER_ID=$(curl -s http://localhost:5128/api/dossiers | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')")

echo "DossierId=$DOSSIER_ID"

if [ -n "$DOSSIER_ID" ]; then
  curl -X POST http://localhost:5128/api/documents/metadata \
    -H "Content-Type: application/json" \
    -d "{\"dossierId\":\"$DOSSIER_ID\",\"fileName\":\"test.pdf\",\"originalFileName\":\"test.pdf\",\"contentType\":\"application/pdf\",\"storagePath\":\"/tmp/test.pdf\",\"sizeBytes\":12345,\"category\":\"Piece\"}"
  echo ""
fi

echo "DOCUMENTS:"
curl http://localhost:5128/api/documents
echo ""

echo "DASHBOARD:"
curl http://localhost:5128/api/dashboard
echo ""

git add .
git commit -m "Sprint 4 - Documents API linked to dossiers" || true
git push || true

echo "SPRINT 4 TERMINE"
