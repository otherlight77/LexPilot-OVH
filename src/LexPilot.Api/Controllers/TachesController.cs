using LexPilot.Domain.Taches;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/taches")]
public class TachesController : ControllerBase
{
    private readonly AppDbContext _db;

    public TachesController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetTaches()
    {
        var taches = await _db.Taches
            .Where(x => !x.IsArchived)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .ToListAsync();

        return Ok(taches);
    }

    [HttpPost]
    public async Task<IActionResult> CreateTache(Tache tache)
    {
        tache.Id = Guid.NewGuid();
        tache.CreatedAtUtc = DateTime.UtcNow;

        _db.Taches.Add(tache);
        await _db.SaveChangesAsync();

        return Ok(tache);
    }

    [HttpPut("{id:guid}/done")]
    public async Task<IActionResult> MarkDone(Guid id)
    {
        var tache = await _db.Taches.FindAsync(id);
        if (tache == null) return NotFound();

        tache.Statut = "Terminee";
        await _db.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Archive(Guid id)
    {
        var tache = await _db.Taches.FindAsync(id);
        if (tache == null) return NotFound();

        tache.IsArchived = true;
        await _db.SaveChangesAsync();

        return NoContent();
    }
}
