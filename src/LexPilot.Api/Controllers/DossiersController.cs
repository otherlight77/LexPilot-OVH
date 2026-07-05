using LexPilot.Domain.Dossiers;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/dossiers")]
public class DossiersController : ControllerBase
{
    private readonly AppDbContext _db;

    public DossiersController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetDossiers([FromQuery] string? search = null)
    {
        var query = _db.Dossiers.Include(x => x.Client).Where(x => !x.IsArchived);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var value = search.ToLower();
            query = query.Where(x =>
                x.Numero.ToLower().Contains(value) ||
                x.Titre.ToLower().Contains(value) ||
                x.TypeAffaire.ToLower().Contains(value) ||
                (x.Client != null && (
                    x.Client.FirstName.ToLower().Contains(value) ||
                    x.Client.LastName.ToLower().Contains(value)
                )));
        }

        var dossiers = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .Select(x => new
            {
                x.Id,
                x.Numero,
                x.Titre,
                x.TypeAffaire,
                x.Statut,
                x.Juridiction,
                x.ClientId,
                Client = x.Client == null ? null : new { x.Client.Id, x.Client.FirstName, x.Client.LastName, x.Client.Email },
                x.CreatedAtUtc
            })
            .ToListAsync();

        return Ok(dossiers);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetDossier(Guid id)
    {
        var dossier = await _db.Dossiers.Include(x => x.Client).FirstOrDefaultAsync(x => x.Id == id && !x.IsArchived);
        return dossier == null ? NotFound() : Ok(dossier);
    }

    [HttpPost]
    public async Task<IActionResult> CreateDossier(Dossier dossier)
    {
        var clientExists = await _db.Clients.AnyAsync(x => x.Id == dossier.ClientId && !x.IsArchived);
        if (!clientExists) return BadRequest("Client introuvable.");

        dossier.Id = Guid.NewGuid();
        dossier.CreatedAtUtc = DateTime.UtcNow;

        _db.Dossiers.Add(dossier);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetDossier), new { id = dossier.Id }, dossier);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateDossier(Guid id, Dossier input)
    {
        var dossier = await _db.Dossiers.FindAsync(id);
        if (dossier == null || dossier.IsArchived) return NotFound();

        dossier.Numero = input.Numero;
        dossier.Titre = input.Titre;
        dossier.TypeAffaire = input.TypeAffaire;
        dossier.Statut = input.Statut;
        dossier.Juridiction = input.Juridiction;
        dossier.Notes = input.Notes;
        dossier.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> ArchiveDossier(Guid id)
    {
        var dossier = await _db.Dossiers.FindAsync(id);
        if (dossier == null) return NotFound();

        dossier.IsArchived = true;
        dossier.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return NoContent();
    }
}
