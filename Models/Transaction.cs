using System;
using System.ComponentModel.DataAnnotations;

public class Transaction
{
    public int Id { get; set; }

    public int UserId { get; set; } = 1; // sementara hardcode

    [Required]
    public string Type { get; set; } // Income, Expense, Transfer

    [Required]
    public decimal Amount { get; set; }

    [Required]
    public string Category { get; set; }

    public string? Destination { get; set; }

    public string? Note { get; set; }

    public DateTime Createdate { get; set; } 

    public bool IsRecurring { get; set; }
}