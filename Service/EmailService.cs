using Microsoft.Extensions.Logging;

public class EmailService
{
    private readonly ILogger<EmailService> _logger;

    public EmailService(ILogger<EmailService> logger)
    {
        _logger = logger;
    }

    public void Send(string to, string subject, string htmlBody)
    {
        EmailHelper.SendEmail(to, subject, htmlBody, _logger);
    }
}