public class Config
{
    public string ConfigKey { get; set; } = string.Empty;
    public string ConfigValue { get; set; } = string.Empty;
    public string? Description { get; set; }
    
    public string? Creator { get; set; }
    public DateTime? CreateDate { get; set; }
    public string? Auditor { get; set; }
    public DateTime? AuditDate { get; set; }
}
