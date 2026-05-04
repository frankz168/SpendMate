using System;
using System.ComponentModel.DataAnnotations;

public class Expense
{
    public int Id { get; set; }

    public int UserId { get; set; } = 1; // sementara hardcode

    [Required]
    public decimal Amount { get; set; }

    [Required]
    public string Category { get; set; }

    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.Now;
}