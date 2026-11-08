To make your scraping and alerting process run automatically in the background, you should handle it on the OS layer (Fedora) rather than keeping a Python script running forever in code.
While you could write an infinite loop in Python using while True: and time.sleep(), it is highly inefficient for a local desktop environment. If your Python script crashes, runs out of memory, or your machine reboots, the entire background pipeline dies silently.
By leveraging systemd—Fedora’s native system and service manager—the OS takes full responsibility for waking up your scripts, managing resources, logging errors, and ensuring things run reliably.

The Recommended Setup: Systemd Timer + Service

The cleanest approach on Fedora is to split your app into two completely separate decoupled parts:
1. The Scraper & Processor Pipeline: Run as a headless script by a systemd timer every few hours.
2. The Flet GUI Dashboard: Run on-demand by you whenever you click its desktop icon or open it from your terminal. Both simply read and write to the exact same local SQLite database file.
Here is exactly how to configure this on your Fedora host using a User-level systemd service (so you don't need sudo or root privileges).

Step 1: Create the Systemd Service File

This file tells Fedora what script to run. Create a file inside your user directory:
~/.config/systemd/user/cyber-fetch.service
ini
[Unit]
Description=Fetch cyber feeds, normalize data via Gemini, and update SQLite DB
After=network.target

[Service]
Type=oneshot
WorkingDirectory=%h/path/to/your/project
ExecStart=%h/.virtualenvs/your_env/bin/python scraper_pipeline.py
StandardOutput=journal
StandardError=journal
Use code with caution.
(Note: Replace path/to/your/project and the Python virtual environment path with your actual paths. %h automatically translates to your home directory, /home/username).

Step 2: Create the Systemd Timer File

This file tells Fedora when to run the service. Create a matching file right next to it:
~/.config/systemd/user/cyber-fetch.timer
ini
[Unit]
Description=Run the Cyber Fetch service every 4 hours

[Timer]
# Wait 5 minutes after booting before running the first time
OnBootSec=5min
# Run every 4 hours thereafter
OnUnitActiveSec=4h
Persistent=true

[Install]
WantedBy=timers.target
Use code with caution.

Step 3: Enable and Start the Timer

Open your Fedora terminal and run the following commands to register your new background task:
bash
# Reload systemd to detect your new files
systemctl --user daemon-reload

# Start the timer immediately and enable it to persist across reboots
systemctl --user enable --now cyber-fetch.timer
Use code with caution.
To verify it's working and see when it is scheduled to run next, use:
bash
systemctl --user list-timers
Use code with caution.

Crucial Design Choice: Triggering Desktop Notifications

Since your background script runs via systemd independently of the Flet GUI, how do you get notified on GNOME?
Inside your scraper_pipeline.py script—right after a new incident successfully passes through Gemini and saves to your SQLite DB—you can use Python to send a native D-Bus signal straight to Fedora’s notification daemon:
python
import subprocess


def send_fedora_notification(title, message):
  # Uses Fedora's native notify-send utility
  subprocess.run([
      "notify-send",
      "-i",
      "security-high",  # Uses a native system shield icon
      title,
      message,
  ])


# Example execution inside your database ingestion loop:
# send_fedora_notification("New Critical CVE Detected", f"{event.source_id} has been added to your local database. Click to open lab.")
Use code with caution.
When systemd runs your script in the background, a crisp native notification will pop up on your Fedora desktop. You can then open your Flet dashboard whenever you have time, see the unread alerts, and start diving into the labs and summaries!
Would you like help writing the basic scraper_pipeline.py script structure that ties the raw requests fetch, Gemini API call, and SQLite entry saving together?

Better Alternatives?

Flet is great for Python, but given your goals—maximizing learning and avoiding web overhead—there are two other fantastic options:
• Go with Flet (Python): Keep this if you want the absolute fastest development time and want to focus entirely on security concepts and database structure rather than learning a new language.
• The Go + Wails Alternative: If your goal is to truly strengthen your programming skills, learning Go is highly valued in cybersecurity (many modern tools, exploits, and scanners are written in Go). Wails lets you write a lightning-fast native backend in Go, paired with a simple HTML/CSS/JS frontend (no complex frameworks needed) that uses an incredibly tiny amount of RAM on Fedora.
• The Rust + Tauri Alternative: Rust is the ultimate language for modern cybersecurity (memory safety, reverse engineering, writing secure firmware). Tauri lets you build local desktop apps using Rust for the logic and a lightweight web frontend. It has a steeper learning curve but provides the ultimate boost to your engineering resume.
The Verdict: Stick with Flet if you want to focus on data and cyber concepts immediately. Switch to Wails (Go) or Tauri (Rust) if you want to push your programming capabilities to the absolute limit.

Project & Script Architecture

Using the Gemini API is a great choice. Local models like Ollama are fun but will cook your host's CPU/GPU every time you fetch data. Gemini has an excellent free/low-cost tier and handles data structuring flawlessly using its structured JSON output mode.
Your pipeline should be split into distinct, decoupled scripts orchestrated by a simple cron job or systemd timer on Fedora.
[Cron / Systemd Timer]
       │
       ▼
 1. Scraper Script ──► [ Raw JSON/Feed ]
       │
       ▼
 2. Gemini Processor ──► [ Normalized Structured Data ]
       │
       ▼
 3. DB Ingestion ──► [ SQLite DB ] ──► 4. Flet Dashboard / Desktop Notification

Step 1: The Scraper Script

Use requests or feedparser to hit security feeds (like the CISA KEV JSON feed, NVD API, or cyber RSS feeds). It fetches raw text data, extracts fields, and passes them to the next step.

Step 2: Gemini API Integration (Using Structured Outputs)

Instead of letting the LLM wander, use Gemini's Structured Output (JSON Schema) feature. You pass it the raw text and force it to return a precise JSON dictionary matching your object classes.

Database & Python Object Design

Using Object-Relational Mapping (ORM) like SQLAlchemy (or SQLModel, which pairs beautifully with Python type hints) lets you manipulate database rows as standard Python classes.
Your proposed three-table structure is elegant and clean. Here is how you can design the tables and map them to Object Oriented Python classes:

1. Database Schema Design

    ┌──────────────────────────────────┐
    │              events              │
    ├──────────────────────────────────┤
    │ id (PK)                          │◄──────┐
    │ source_id (e.g., CVE-2026-1234)   │       │
    │ technical_url                    │       │
    │ severity                         │       │ (1-to-1)
    │ fetched_at                       │       │
    └──────────────────────────────────┘       │
                      │                        │
                      │ (1-to-Many)            │
                      ▼                        ▼
    ┌──────────────────────────────────┐ ┌──────────────────────────────────┐
    │          notifications           │ │             answers              │
    ├──────────────────────────────────┤ ├──────────────────────────────────┤
    │ id (PK)                          │ │ id (PK)                          │
    │ event_id (FK)                    │ │ event_id (FK)                    │
    │ is_read                          │ │ plain_english_summary            │
    │ alerted_at                       │ │ how_it_happens                   │
    │                                  │ │ how_to_protect                   │
    │                                  │ │ test_scenario_lab               │
    └──────────────────────────────────┘ └──────────────────────────────────┘

2. The Python Class Implementation (SQLAlchemy / SQLModel)

By designing your tables like this, your Python scripts can manipulate the database seamlessly using Object-Oriented Principles:
python
from datetime import datetime
from typing import Optional
from sqlmodel import Field, Relationship, SQLModel


# 1. Core Event Metadata Table
class CyberEvent(SQLModel, table=True):
  __tablename__ = "events"

  id: Optional[int] = Field(default=None, primary_key=True)
  source_id: str = Field(
      index=True, unique=True
  )  # e.g., 'CVE-2026-5532' or 'breach-uber'
  technical_url: str
  severity: str  # 'Low', 'Medium', 'High', 'Critical'
  fetched_at: datetime = Field(default_factory=datetime.utcnow)

  # Relationships
  answer: "CyberAnswer" = Relationship(back_populates="event")
  notifications: list["Notification"] = Relationship(back_populates="event")


# 2. LLM Generated Content (Kept separate to keep queries fast and clean)
class CyberAnswer(SQLModel, table=True):
  __tablename__ = "answers"

  id: Optional[int] = Field(default=None, primary_key=True)
  event_id: int = Field(foreign_key="events.id", unique=True)

  # Formatted human-friendly fields populated by Gemini API
  plain_english_summary: str
  how_it_happens: str
  how_to_protect: str
  test_scenario_lab: (
      str  # A mock scenario or local command you can run to understand it
  )

  event: CyberEvent = Relationship(back_populates="answer")


# 3. Notification Queue Table
class Notification(SQLModel, table=True):
  __tablename__ = "notifications"

  id: Optional[int] = Field(default=None, primary_key=True)
  event_id: int = Field(foreign_key="events.id")
  is_read: bool = Field(default=False)
  alerted_at: datetime = Field(default_factory=datetime.utcnow)

  event: CyberEvent = Relationship(back_populates="notifications")
Use code with caution.

Why this data structure works perfectly for your UI

When your Flet desktop application boots up, it can easily query the Notification table where is_read == False. It can render badges over your UI tabs, flash desktop notifications via Fedora's system tray, and fetch the connected CyberAnswer markdown text instantly with zero complex data transformation.
Would you like help writing the Gemini prompt setup with Python typing so it guarantees a clean JSON response that slots perfectly into these database classes?