namespace LexPilot.Domain.Taches;

public class Tache
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Titre { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string Statut { get; set; } = "A faire";
    public string Priorite { get; set; } = "Normale";
    public DateTime? DateEcheance { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsArchived { get; set; }
}
