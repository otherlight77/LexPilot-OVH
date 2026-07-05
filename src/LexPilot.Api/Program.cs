var builder = WebApplication.CreateBuilder(args);
builder.Services.AddOpenApi();
var app = builder.Build();

app.MapOpenApi();

app.MapGet("/", () => Results.Ok(new { app = "LexPilot OVH", status = "running", version = "0.1.0" }));
app.MapGet("/health", () => Results.Ok(new { status = "ok", app = "LexPilot.Api", version = "0.1.0" }));
app.MapGet("/api/dashboard", () => Results.Ok(new { clients = 0, dossiers = 0, documents = 0, message = "LexPilot OVH base operationnelle" }));

app.Run();
