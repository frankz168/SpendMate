using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SpendMate.Models;
using System.Diagnostics;

namespace SpendMate.Controllers;

[Authorize]
public class UserController : Controller
{
    private readonly IUserRepository _userRepo;
    private readonly ILogger<UserController> _logger;

    public UserController(IUserRepository userRepo, ILogger<UserController> logger)
    {
        _userRepo = userRepo;
        _logger = logger;
    }

    public IActionResult Index()
    {
        var users = _userRepo.GetAll();
        return View(users);
    }

    [HttpPost]
    public IActionResult Save(int Id, string Name, string PhoneNumber, string Username, string? Password)
    {
        try
        {
            var user = new User
            {
                Id = Id,
                Name = Name,
                PhoneNumber = PhoneNumber,
                Username = Username
            };

            if (Id == 0)
            {
                if (string.IsNullOrEmpty(Password))
                {
                    return BadRequest("Password is required for new users.");
                }
                _userRepo.Create(user, Password);
            }
            else
            {
                _userRepo.Update(user, Password);
            }

            TempData["Success"] = "User saved successfully!";
            return RedirectToAction("Index");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving user.");
            return RedirectToAction("Index");
        }
    }

    [HttpPost]
    public IActionResult Delete(int id)
    {
        try
        {
            // Do not allow deleting the currently logged in user to prevent lockouts
            string? currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (currentUserId != null && currentUserId == id.ToString())
            {
                return BadRequest("You cannot delete your own account.");
            }

            _userRepo.Delete(id);
            return Ok();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting user.");
            return BadRequest(ex.Message);
        }
    }
}
