using Microsoft.AspNetCore.Mvc;

namespace LexPilot.Api.Controllers;

[ApiController]
[Route("api/v1")]
public class V1ModulesController : ControllerBase
{
    [HttpGet("modules")]
    public IActionResult Modules() => Ok(new
    {
        version = "V1",
        modules = new[]
        {
            "Agenda", "Facturation", "Portail client", "Signature électronique",
            "Téléphonie", "IA", "OCR", "Légifrance", "Marketing SEO", "Office 365"
        }
    });

    [HttpGet("agenda")]
    public IActionResult Agenda() => Ok(new[]
    {
        new { date = "Aujourd'hui", titre = "Rendez-vous client Dupont", type = "RDV" },
        new { date = "Demain", titre = "Audience TJ Lille", type = "Audience" }
    });

    [HttpGet("facturation")]
    public IActionResult Facturation() => Ok(new { caMois = 0, factures = 0, honorairesAttente = 0 });

    [HttpGet("portal")]
    public IActionResult Portal() => Ok(new { clientsConnectes = 0, documentsDeposes = 0, signaturesEnAttente = 0 });

    [HttpGet("ia")]
    public IActionResult Ia() => Ok(new { analyses = 0, resumes = 0, documentsAnalyse = 0, status = "pret" });

    [HttpGet("marketing")]
    public IActionResult Marketing() => Ok(new { visiteurs = 0, prospects = 0, seo = "a connecter" });

    [HttpGet("signature")]
    public IActionResult Signature() => Ok(new { provider = "Yousign / DocuSign / Universign", status = "a configurer" });

    [HttpGet("telephonie")]
    public IActionResult Telephonie() => Ok(new { appels = 0, provider = "Teams / OVH / Aircall / 3CX", status = "a configurer" });
}
