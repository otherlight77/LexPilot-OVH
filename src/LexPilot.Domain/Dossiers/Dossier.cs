using LexPilot.Domain.Clients;

namespace LexPilot.Domain.Dossiers;

public class Dossier
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Numero { get; set; } = string.Empty;
    public string Titre { get; set; } = string.Empty;
    public string TypeAffaire { get; set; } = string.Empty;
    public string Statut { get; set; } = "Ouvert";
    public string? Juridiction { get; set; }
    public string? Notes { get; set; }
    public Guid ClientId { get; set; }
    public Client? Client { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsArchived { get; set; }
}
