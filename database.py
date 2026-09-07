import sqlite3
import json
import re
from typing import List, Dict, Optional, Any
from contextlib import contextmanager

DATABASE_FILE = "ontoc.db"

def init_database():
    """Initialize the database with required tables."""
    conn = sqlite3.connect(DATABASE_FILE)
    conn.execute("PRAGMA foreign_keys = ON")

    # Create tables
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS systems (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            realizes TEXT,
            description TEXT,
            determinism TEXT,
            reversibility TEXT,
            exactness TEXT,
            realization_type TEXT,
            computation_model TEXT
        );

        CREATE TABLE IF NOT EXISTS substrates (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT
        );

        CREATE TABLE IF NOT EXISTS system_substrates (
            system_id TEXT REFERENCES systems(id),
            substrate_id TEXT REFERENCES substrates(id),
            PRIMARY KEY (system_id, substrate_id)
        );

        CREATE TABLE IF NOT EXISTS examples (
            id TEXT PRIMARY KEY,
            system_id TEXT REFERENCES systems(id),
            label TEXT,
            url TEXT,
            description TEXT,
            operations TEXT,
            speed_category TEXT,
            scale_category TEXT,
            energy_per_operation TEXT
        );

        -- One substrate per system (see migrations/005). Enforced rather than
        -- assumed: a second link would silently reappear in the substrate filter.
        CREATE UNIQUE INDEX IF NOT EXISTS idx_system_substrates_single
            ON system_substrates(system_id);

        DROP VIEW IF EXISTS substrate_category_summary;
        DROP VIEW IF EXISTS systems_with_realization_category;
        DROP VIEW IF EXISTS realization_category_summary;

        CREATE VIEW substrate_category_summary AS
            SELECT
                s.id,
                s.name,
                s.description,
                COUNT(ss.system_id) AS system_count
            FROM substrates s
            JOIN system_substrates ss ON s.id = ss.substrate_id
            GROUP BY s.id, s.name, s.description
            ORDER BY s.name;

        CREATE VIEW systems_with_realization_category AS
            SELECT
                s.*,
                CASE
                WHEN lower(s.realization_type) LIKE '%variational%' THEN 'Variational'
                WHEN lower(s.realization_type) LIKE '%statistical%' THEN 'Statistical'
                WHEN lower(s.realization_type) LIKE '%stochastic%' THEN 'Statistical'
                WHEN lower(s.realization_type) LIKE '%probabilistic%' THEN 'Statistical'
                WHEN lower(s.realization_type) LIKE '%thermal%' THEN 'Statistical'
                WHEN lower(s.realization_type) LIKE '%analog%' THEN 'Statistical'
                WHEN lower(s.realization_type) LIKE '%anneal%' THEN 'Statistical'
                ELSE 'Procedural'
            END AS realization_category
        FROM systems s;

        CREATE VIEW realization_category_summary AS
            SELECT
                realization_category AS name,
            COUNT(*) AS system_count,
            CASE realization_category
                WHEN 'Statistical' THEN 'Systems driven by probability, noise, or statistical methods.'
                WHEN 'Variational' THEN 'Systems that rely on variational optimization or quantum-inspired tuning.'
                ELSE 'Deterministic, procedural CMOS/logic realizations (cores, GPUs, ASICs, etc.).'
            END AS description
        FROM systems_with_realization_category
        WHERE realization_category IS NOT NULL
        GROUP BY realization_category
        ORDER BY CASE realization_category
            WHEN 'Statistical' THEN 1
            WHEN 'Variational' THEN 2
            WHEN 'Procedural' THEN 3
            ELSE 99
        END;
    """)

    conn.commit()
    conn.close()

@contextmanager
def get_db_connection():
    """Get a database connection with foreign keys enabled."""
    conn = sqlite3.connect(DATABASE_FILE)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def _parse_json_field(value: Optional[str]) -> Optional[List[str]]:
    if value is None:
        return None
    trimmed = value.strip()
    if trimmed == "":
        return None
    try:
        parsed = json.loads(trimmed)
    except json.JSONDecodeError:
        return [trimmed]
    if isinstance(parsed, list):
        return parsed
    return [parsed]

def get_system(system_id: str) -> Optional[Dict[str, Any]]:
    """Get a system by ID with its substrates and examples."""
    with get_db_connection() as conn:
        # Get system
        system = conn.execute(
            "SELECT * FROM systems WHERE id = ?", (system_id,)
        ).fetchone()

        if not system:
            return None

        system = dict(system)

        # Get substrates
        substrates = conn.execute("""
            SELECT s.* FROM substrates s
            JOIN system_substrates ss ON s.id = ss.substrate_id
            WHERE ss.system_id = ?
        """, (system_id,)).fetchall()
        system['substrates'] = [dict(row) for row in substrates]

        # Get examples
        examples = conn.execute(
            "SELECT * FROM examples WHERE system_id = ?", (system_id,)
        ).fetchall()
        system['examples'] = [dict(row) for row in examples]

        # Parse JSON fields
        system['computation_model'] = _parse_json_field(system['computation_model'])

        for example in system['examples']:
            example['operations'] = _parse_json_field(example['operations'])
            # Add thumbnail URL for YouTube videos
            if example['url']:
                example['thumbnail_url'] = get_youtube_thumbnail(example['url'])

        return system

def get_substrate(substrate_id: str) -> Optional[Dict[str, Any]]:
    """Get a substrate by ID."""
    with get_db_connection() as conn:
        substrate = conn.execute(
            "SELECT * FROM substrates WHERE id = ?", (substrate_id,)
        ).fetchone()
        return dict(substrate) if substrate else None

def get_systems_by_substrate(substrate_id: str) -> List[Dict[str, Any]]:
    """Get all systems that use a specific substrate."""
    with get_db_connection() as conn:
        systems = conn.execute("""
            SELECT s.* FROM systems s
            JOIN system_substrates ss ON s.id = ss.system_id
            WHERE ss.substrate_id = ?
            ORDER BY s.name
        """, (substrate_id,)).fetchall()

        result = []
        for system in systems:
            system_dict = dict(system)
            system_dict['computation_model'] = _parse_json_field(system_dict['computation_model'])
            result.append(system_dict)

        return result

def get_all_systems() -> List[Dict[str, Any]]:
    """Get all systems."""
    with get_db_connection() as conn:
        systems = conn.execute("SELECT * FROM systems ORDER BY name").fetchall()
        substrate_rows = conn.execute("""
            SELECT ss.system_id, s.id, s.name, s.description
            FROM system_substrates ss
            JOIN substrates s ON s.id = ss.substrate_id
        """).fetchall()
        substrate_map: Dict[str, List[Dict[str, Any]]] = {}
        for row in substrate_rows:
            substrate_map.setdefault(row['system_id'], []).append({
                'id': row['id'],
                'name': row['name'],
                'description': row['description']
            })

        result = []
        for system in systems:
            system_dict = dict(system)
            system_dict['computation_model'] = _parse_json_field(system_dict['computation_model'])
            system_dict['substrates'] = substrate_map.get(system_dict['id'], [])
            result.append(system_dict)
        return result

def get_all_substrates() -> List[Dict[str, Any]]:
    """Get all substrates."""
    with get_db_connection() as conn:
        substrates = conn.execute("SELECT * FROM substrates ORDER BY name").fetchall()
        return [dict(row) for row in substrates]


def get_substrate_categories() -> List[Dict[str, Any]]:
    with get_db_connection() as conn:
        rows = conn.execute("SELECT id, name, description, system_count FROM substrate_category_summary ORDER BY name").fetchall()
        return [dict(row) for row in rows]


def get_realization_categories() -> List[Dict[str, Any]]:
    with get_db_connection() as conn:
        rows = conn.execute(
            """
            SELECT name, description, system_count
            FROM realization_category_summary
            ORDER BY CASE name
                WHEN 'Statistical' THEN 1
                WHEN 'Variational' THEN 2
                WHEN 'Procedural' THEN 3
                ELSE 99
            END
            """
        ).fetchall()
        return [dict(row) for row in rows]

def get_systems_by_property(property_name: str, property_value: str) -> List[Dict[str, Any]]:
    """Get all systems that have a specific property value."""
    if property_name == "computation_model":
        with get_db_connection() as conn:
            systems = conn.execute("""
                SELECT * FROM systems
                WHERE computation_model LIKE ?
                ORDER BY name
            """, (f'%"{property_value}"%',)).fetchall()
        result = []
        for system in systems:
            system_dict = dict(system)
            system_dict['computation_model'] = _parse_json_field(system_dict['computation_model'])
            result.append(system_dict)
        return result

    if property_name == "realization_type":
        with get_db_connection() as conn:
            systems = conn.execute("""
                SELECT * FROM systems_with_realization_category
                WHERE realization_category = ?
                ORDER BY name
            """, (property_value,)).fetchall()
        result = []
        for system in systems:
            system_dict = dict(system)
            system_dict['computation_model'] = _parse_json_field(system_dict['computation_model'])
            result.append(system_dict)
        return result

    with get_db_connection() as conn:
        systems = conn.execute(f"""
            SELECT * FROM systems
            WHERE {property_name} = ?
            ORDER BY name
        """, (property_value,)).fetchall()

    result = []
    for system in systems:
        system_dict = dict(system)
        system_dict['computation_model'] = _parse_json_field(system_dict['computation_model'])
        result.append(system_dict)

    return result

def get_unique_property_values(property_name: str) -> List[str]:
    """Get all unique values for a given property."""
    if property_name == "computation_model":
        # For JSON array fields, we need to extract unique values differently
        with get_db_connection() as conn:
            systems = conn.execute("SELECT computation_model FROM systems WHERE computation_model IS NOT NULL").fetchall()
        values = set()
        for row in systems:
            parsed = _parse_json_field(row[0])
            if parsed is None:
                continue
            if isinstance(parsed, list):
                values.update(parsed)
            else:
                values.add(parsed)
        return sorted(list(values))

    if property_name == "realization_type":
        return [entry["name"] for entry in get_realization_categories()]

    with get_db_connection() as conn:
        values = conn.execute(f"""
            SELECT DISTINCT {property_name} FROM systems
            WHERE {property_name} IS NOT NULL
            ORDER BY {property_name}
        """).fetchall()
        return [row[0] for row in values]

def get_youtube_thumbnail(url: str) -> Optional[str]:
    """Extract YouTube thumbnail URL from video URL."""
    if not url:
        return None

    # YouTube video ID patterns - more precise matching
    patterns = [
        r'(?:youtube\.com/watch\?v=)([0-9A-Za-z_-]{11})(?:&|$)',  # youtube.com/watch?v=ID
        r'(?:youtube\.com/embed/)([0-9A-Za-z_-]{11})(?:\?|$)',    # youtube.com/embed/ID
        r'(?:youtu\.be/)([0-9A-Za-z_-]{11})(?:\?|$)',             # youtu.be/ID
        r'(?:youtube\.com/v/)([0-9A-Za-z_-]{11})(?:\?|$)',        # youtube.com/v/ID
    ]

    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            video_id = match.group(1)
            # Validate video ID length (YouTube IDs are exactly 11 characters)
            if len(video_id) == 11:
                return f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"

    return None
