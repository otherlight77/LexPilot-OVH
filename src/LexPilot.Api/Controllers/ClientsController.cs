using LexPilot.Domain.Clients;
using LexPilot.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/clients")]
public class ClientsController : ControllerBase
{
    private readonly AppDbContext _db;

    public ClientsController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Client>>> GetClients([FromQuery] string? search = null)
    {
        var query = _db.Clients
            .Where(x => !x.IsArchived)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var value = search.ToLower();
            query = query.Where(x =>
                x.FirstName.ToLower().Contains(value) ||
                x.LastName.ToLower().Contains(value) ||
                (x.CompanyName != null && x.CompanyName.ToLower().Contains(value)) ||
                (x.Email != null && x.Email.ToLower().Contains(value)));
        }

        var clients = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .ToListAsync();

        return Ok(clients);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<Client>> GetClient(Guid id)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null || client.IsArchived)
            return NotFound();

        return Ok(client);
    }

    [HttpPost]
    public async Task<ActionResult<Client>> CreateClient(Client client)
    {
        client.Id = Guid.NewGuid();
        client.CreatedAtUtc = DateTime.UtcNow;

        _db.Clients.Add(client);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetClient), new { id = client.Id }, client);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateClient(Guid id, Client input)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null || client.IsArchived)
            return NotFound();

        client.FirstName = input.FirstName;
        client.LastName = input.LastName;
        client.CompanyName = input.CompanyName;
        client.Email = input.Email;
        client.Phone = input.Phone;
        client.Address = input.Address;
        client.City = input.City;
        client.PostalCode = input.PostalCode;
        client.Notes = input.Notes;
        client.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> ArchiveClient(Guid id)
    {
        var client = await _db.Clients.FindAsync(id);

        if (client == null)
            return NotFound();

        client.IsArchived = true;
        client.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        return NoContent();
    }
}
