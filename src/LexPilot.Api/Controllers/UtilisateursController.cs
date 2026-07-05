using LexPilot.Domain.Utilisateurs;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/utilisateurs")]
public class UtilisateursController : ControllerBase
{
    private readonly AppDbContext _db;

    public UtilisateursController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var users = await _db.Utilisateurs
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync();

        return Ok(users);
    }

    [HttpPost]
    public async Task<IActionResult> Create(Utilisateur user)
    {
        user.Id = Guid.NewGuid();
        user.CreatedAtUtc = DateTime.UtcNow;
        _db.Utilisateurs.Add(user);
        await _db.SaveChangesAsync();
        return Ok(user);
    }
}
