public static class ApplicationConfig
{
    public static class Email
    {
        public static string FromEmail = "franky.sutanto93@gmail.com";
        public static string Password = "eyanrqtkkapeviyb"; //gmail spendmate apps password
        public static string SmtpHost = "smtp.gmail.com";
        public static int SmtpPort = 587;
    }

    public static class Report
    {
        public static List<string> EmailTo = new List<string>
        {
            "franky.sutanto93@gmail.com",
            "evelineamalia0812@gmail.com"
        };

        public static TimeSpan DailyTime = new TimeSpan(07, 10, 0);
        public static TimeSpan WeeklyTime = new TimeSpan(07, 10, 0);
        public static TimeSpan MonthlyTime = new TimeSpan(07, 10, 0);

        public static DayOfWeek WeeklyDay = DayOfWeek.Sunday;
        public static int MonthlyDay = 1;
    }
    
      public static decimal MonthlyBudget = 6500000;
}