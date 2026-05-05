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
        public static string EmailTo = "franky.sutanto93@gmail.com";

        public static TimeSpan DailyTime = new TimeSpan(21, 0, 0);
        public static TimeSpan WeeklyTime = new TimeSpan(21, 0, 0);
        public static TimeSpan MonthlyTime = new TimeSpan(21, 0, 0);

        public static DayOfWeek WeeklyDay = DayOfWeek.Sunday;
        public static int MonthlyDay = 1;
    }
    
      public static decimal Budget = 7000000;
}