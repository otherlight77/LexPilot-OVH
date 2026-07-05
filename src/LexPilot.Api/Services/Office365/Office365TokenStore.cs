using System.Text.Json;

namespace LexPilot.Api.Services.Office365;

public class Office365TokenStore
{
    private readonly string _file = "/opt/lexpilot-ovh/data/office365_tokens.json";

    public async Task SaveAsync(Office365TokenData data)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_file)!);
        var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(_file, json);
    }

    public async Task<Office365TokenData?> LoadAsync()
    {
        if (!File.Exists(_file)) return null;
        var json = await File.ReadAllTextAsync(_file);
        return JsonSerializer.Deserialize<Office365TokenData>(json);
    }
}

public class Office365TokenData
{
    public string AccessToken { get; set; } = "";
    public string RefreshToken { get; set; } = "";
    public DateTime ExpiresAtUtc { get; set; }
}
