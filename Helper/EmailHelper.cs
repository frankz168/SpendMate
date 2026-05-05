using MailKit.Net.Smtp;
using MimeKit;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

public static class EmailHelper
{
    public static void SendEmail(
        string to,
        string subject,
        string htmlBody,
        ILogger logger)
    {
        var sw = Stopwatch.StartNew();

        try
        {
            logger.LogInformation(
                "📧 [Email] START | To={To}, Subject={Subject}",
                to, subject);

            var email = new MimeMessage();

            email.From.Add(MailboxAddress.Parse(ApplicationConfig.Email.FromEmail));
            email.To.Add(MailboxAddress.Parse(to));
            email.Subject = subject;

            email.Body = new TextPart("html")
            {
                Text = htmlBody
            };

            using var smtp = new SmtpClient();

            logger.LogInformation("🔌 [Email] Connecting to SMTP {Host}:{Port}",
                ApplicationConfig.Email.SmtpHost,
                ApplicationConfig.Email.SmtpPort);

            smtp.Connect(
                ApplicationConfig.Email.SmtpHost,
                ApplicationConfig.Email.SmtpPort,
                false
            );

            logger.LogInformation("🔐 [Email] Authenticating...");

            smtp.Authenticate(
                ApplicationConfig.Email.FromEmail,
                ApplicationConfig.Email.Password
            );

            logger.LogInformation("📤 [Email] Sending...");

            smtp.Send(email);

            smtp.Disconnect(true);

            sw.Stop();

            logger.LogInformation(
                "✅ [Email] SUCCESS | To={To}, Duration={Ms}ms",
                to,
                sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "❌ [Email] FAILED | To={To}, Subject={Subject}",
                to, subject);

            throw;
        }
    }
}