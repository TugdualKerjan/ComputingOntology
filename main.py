from fastapi import FastAPI, Request, HTTPException
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, RedirectResponse
from urllib.parse import urlencode
import database

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Disable template caching to fix the unhashable type error
templates.env.cache = {}

@app.on_event("startup")
async def startup_event():
    database.init_database()

# Dimensions the search page can filter on. Every tag, pill and category link in
# the app points back here as /?<dimension>=<value>, so there is one search
# surface instead of a page per property value.
FILTER_DIMENSIONS = [
    "substrate",
    "determinism",
    "reversibility",
    "exactness",
    "computation_model",
    "realization_type",
]

# Dimensions rendered as pill rows. The rest filter fine but have vocabularies
# too large to enumerate (realization_type alone has 158 distinct values), so
# they are reachable by link and shown as removable chips.
PILL_DIMENSIONS = ["substrate", "determinism", "exactness", "computation_model"]

DIMENSION_LABELS = {
    "substrate": "substrate",
    "determinism": "determinism",
    "reversibility": "reversibility",
    "exactness": "exactness",
    "computation_model": "model",
    "realization_type": "realization",
}


def search_url(dimension: str, value: str) -> str:
    """Link into the search page with one filter pre-activated."""
    return "/?" + urlencode({dimension: value})


@app.get("/", response_class=HTMLResponse)
async def index(request: Request, filter: str = None, value: str = None, q: str = ""):
    systems = database.get_all_systems()

    # Repeatable params: /?substrate=Optical&substrate=Quantum&exactness=exact
    active_filters = {
        dimension: request.query_params.getlist(dimension)
        for dimension in FILTER_DIMENSIONS
    }

    # Back-compat with the older single-filter links (/?filter=exactness&value=exact)
    if filter in FILTER_DIMENSIONS and value and value not in active_filters[filter]:
        active_filters[filter].append(value)

    substrates = database.get_all_substrates()
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "systems": systems,
            "substrates": substrates,
            "active_filters": active_filters,
            "text_query": q,
            "filter_dimensions": FILTER_DIMENSIONS,
            "pill_dimensions": PILL_DIMENSIONS,
            "dimension_labels": DIMENSION_LABELS,
        }
    )

@app.get("/categories", response_class=HTMLResponse)
async def categories_page(request: Request):
    substrate_categories = database.get_substrate_categories()
    realization_categories = database.get_realization_categories()
    property_keys = ["determinism", "reversibility", "exactness", "realization_type", "computation_model"]
    property_display = {
        "determinism": "Determinism",
        "reversibility": "Reversibility",
        "exactness": "Exactness",
        "realization_type": "Realization Type",
        "computation_model": "Computation Model"
    }
    properties = []
    for key in property_keys:
        values = database.get_unique_property_values(key)
        if values:
            properties.append({
                "key": key,
                "display": property_display.get(key, key.title()),
                "values": values
            })

    return templates.TemplateResponse(
        request=request,
        name="categories.html",
        context={
            "substrate_categories": substrate_categories,
            "realization_categories": realization_categories,
            "properties": properties
        }
    )

@app.get("/ontoc/systems/{system_id}", response_class=HTMLResponse)
async def system_page(request: Request, system_id: str):
    system = database.get_system(system_id)
    if not system:
        raise HTTPException(status_code=404, detail="System not found")

    return templates.TemplateResponse(
        request=request,
        name="system.html",
        context={"system": system}
    )

@app.get("/ontoc/substrates/{substrate_id}")
async def substrate_redirect(substrate_id: str):
    """Substrates are a filter, not a page: bounce to the search with it applied."""
    substrate = database.get_substrate(substrate_id)
    if not substrate:
        raise HTTPException(status_code=404, detail="Substrate not found")

    return RedirectResponse(search_url("substrate", substrate["name"]), status_code=302)

@app.get("/api/systems")
async def api_systems():
    return database.get_all_systems()

@app.get("/api/substrates")
async def api_substrates():
    return database.get_all_substrates()

@app.get("/api/systems/{system_id}")
async def api_system(system_id: str):
    system = database.get_system(system_id)
    if not system:
        raise HTTPException(status_code=404, detail="System not found")
    return system

# The per-property category pages are gone -- clicking a property filters the
# search instead. Kept as redirects so existing links and bookmarks still land
# somewhere useful. Declared last so /ontoc/systems/... and /ontoc/substrates/...
# match first.
@app.get("/ontoc/{dimension}/{value}")
async def property_redirect(dimension: str, value: str):
    if dimension not in FILTER_DIMENSIONS or dimension == "substrate":
        raise HTTPException(status_code=404, detail="Unknown property")

    return RedirectResponse(search_url(dimension, value), status_code=302)
