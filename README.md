# SpendMate 💸🤖

[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![SQL Server](https://img.shields.io/badge/SQLServer-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io/)
[![Gemini API](https://img.shields.io/badge/Gemini%20API-8E75B2?style=for-the-badge&logo=googlebard&logoColor=white)](https://aistudio.google.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

SpendMate is a next-generation personal finance application that leverages AI to eliminate the friction of manual expense tracking. Using Google's **Gemini API**, SpendMate's "Smart Input" feature parses natural language entries (e.g., *"Spent $15 on coffee at Starbucks yesterday"*) and automatically converts them into structured JSON transaction data, categorizing and logging them seamlessly.

Built with performance and scalability in mind, SpendMate utilizes a robust Clean Architecture pattern on .NET, backed by SQL Server for reliable data persistence and Redis for lightning-fast data retrieval.

## 🚀 Key Features

* **AI Smart Input:** Effortlessly log transactions using conversational language powered by Google Gemini.
* **Lightning Fast:** High-performance caching mechanism using Redis for dashboards and frequent queries.
* **Robust Core:** Reliable relational data storage with SQL Server and Entity Framework Core.
* **Clean Architecture:** Highly testable, maintainable, and decoupled codebase.

## 🛠️ Tech Stack

* **Framework:** C# / .NET (Core/5+) ASP.NET Core Web API / MVC
* **Primary Database:** Microsoft SQL Server
* **Caching:** Redis (StackExchange.Redis / IDistributedCache)
* **AI Integration:** Google Gemini API (via HTTP/REST)
* **ORM:** Entity Framework Core (EF Core)

## 🏗️ System Architecture

SpendMate is designed using **Clean Architecture** to ensure that business logic remains independent of UI, databases, and external services.

* **Domain:** Core entities (`Transaction`, `Category`), enums, and domain rules.
* **Application:** Business logic, use cases, and interfaces (e.g., `IGeminiService`, `ITransactionRepository`).
* **Infrastructure:** External implementations:
    * EF Core DbContext for SQL Server.
    * Redis Caching implementations.
    * Gemini API HTTP client wrappers.
* **Presentation:** ASP.NET Core API Controllers and user interface views.

> See the detailed [Architecture Blueprint](architecture_blueprint.md) for an in-depth breakdown of layer responsibilities.

## 💻 Local Setup & Installation

### Prerequisites

* [.NET SDK](https://dotnet.microsoft.com/download) (Version 5.0 or later)
* [SQL Server](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (Express, Developer, or Docker container)
* [Redis](https://redis.io/download) (Local installation or Docker container)
* A valid [Google Gemini API Key](https://aistudio.google.com/)

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/SpendMate.git
cd SpendMate
```

### 2. Configure Environment Variables

Create an `appsettings.Development.json` file in your Presentation/API project layer (e.g., `SpendMate.API/appsettings.Development.json`) and configure your connection strings and API keys:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=SpendMateDb;User Id=sa;Password=YourStrongPassword123!;TrustServerCertificate=True;",
    "RedisCache": "localhost:6379,abortConnect=false"
  },
  "GeminiSettings": {
    "ApiKey": "YOUR_GEMINI_API_KEY",
    "Endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

*Replace the SQL Server connection string with your local credentials, and insert your actual Gemini API key.*

### 3. Apply Database Migrations

Navigate to the API project directory and run Entity Framework migrations to create your SQL Server schema:

```bash
cd SpendMate.API # Or your presentation layer project folder
dotnet ef database update --project ../SpendMate.Infrastructure
```
*(Adjust the `--project` flag depending on your exact folder structure if Migrations are stored in the Infrastructure layer).*

### 4. Run the Application

Ensure your SQL Server and Redis instances are running, then launch the app:

```bash
dotnet run
```

Navigate to `https://localhost:5001/swagger` (or the port specified in your console) to explore the API endpoints!

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/SpendMate/issues).

## 📝 License

This project is [MIT](https://opensource.org/licenses/MIT) licensed.
