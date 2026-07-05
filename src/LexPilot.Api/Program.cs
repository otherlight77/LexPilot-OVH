using LexPilot.Infrastructure;
using LexPilot.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddControllers();
builder.Services.AddInfrastructure(builder.Configuration);

var app = builder.Build();

app.MapOpenApi();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();
}

app.MapGet("/", () => Results.Ok(new
{
    app = "LexPilot OVH",
    status = "running",
    version = "0.2.0"
}));

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    app = "LexPilot.Api",
    version = "0.2.0"
}));

app.MapGet("/api/dashboard", async (AppDbContext db) => Results.Ok(new
{
    clients = await db.Clients.CountAsync(x => !x.IsArchived),
    dossiers = 0,
    documents = 0,
    message = "Sprint 2 Clients actif"
}));

app.MapControllers();

app.Run();
