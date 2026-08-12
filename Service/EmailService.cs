using MailKit.Net.Smtp;
using MimeKit;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

public class EmailService
{
    private readonly IConfigRepository _config;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfigRepository config, ILogger<EmailService> logger)
    {
        _config = config;
        _logger = logger;
    }

    public virtual void Send(string to, string subject, string htmlBody)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation(
                "📧 [Email] START | To={To}, Subject={Subject}",
                to, subject);

            var email = new MimeMessage();

            string fromEmail = _config.GetString("Email_FromEmail");
            string password = _config.GetString("Email_Password");
            string smtpHost = _config.GetString("Email_SmtpHost");
            int smtpPort = _config.GetInt("Email_SmtpPort", 587);

            email.From.Add(MailboxAddress.Parse(fromEmail));
            email.To.Add(MailboxAddress.Parse(to));
            email.Subject = subject;

            email.Body = new TextPart("html")
            {
                Text = htmlBody
            };

            using var smtp = new SmtpClient();

            _logger.LogInformation("🔌 [Email] Connecting to SMTP {Host}:{Port}",
                smtpHost,
                smtpPort);

            smtp.Connect(
                smtpHost,
                smtpPort,
                false
            );

            _logger.LogInformation("🔐 [Email] Authenticating...");

            smtp.Authenticate(
                fromEmail,
                password
            );

            _logger.LogInformation("📤 [Email] Sending...");

            smtp.Send(email);

            smtp.Disconnect(true);

            sw.Stop();

            _logger.LogInformation(
                "✅ [Email] SUCCESS | To={To}, Duration={Ms}ms",
                to,
                sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "❌ [Email] FAILED | To={To}, Subject={Subject}",
                to, subject);

            throw;
        }
    }
}