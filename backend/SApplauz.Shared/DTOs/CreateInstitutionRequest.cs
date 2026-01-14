namespace SApplauz.Shared.DTOs;

public class CreateInstitutionRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Address { get; set; }
    public int Capacity { get; set; }
    public string? ImagePath { get; set; }
    public string? Website { get; set; }
    public bool IsActive { get; set; } = true;
}






