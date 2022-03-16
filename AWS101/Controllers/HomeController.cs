using Microsoft.AspNetCore.Mvc;

namespace AWS101.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class HomeController : Controller
    {
        [HttpGet]
        public string Get()
        {
            return "Hello from REST API";
        }
    }
}
