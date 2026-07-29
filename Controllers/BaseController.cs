using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

public abstract class BaseController : Controller
{
    protected int GetUserId()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (int.TryParse(idClaim, out int userId))
        {
            return userId;
        }
        return 0; // Or throw exception
    }
}
