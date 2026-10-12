"""Builds the WD Elite knowledge PDFs for the Housing Service Agent's Data Library.

Edit PROJECTS below, then run:  python3 build_docs.py
Facts are written as full sentences that repeat the project name, because the
Data Library splits each file into small chunks and a chunk should still make
sense when it is read on its own.
"""
import html, pathlib, subprocess

OUT = pathlib.Path(__file__).parent / "pdf"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CONTACT = "+91 78541 25632"

# Each place: (name, detail, distance_km, drive_minutes)
PROJECTS = [
    {
        "name": "Varthur Vista", "city": "Bengaluru", "locality": "Varthur, East Bengaluru (Whitefield–Sarjapur belt)",
        "address": "Varthur Main Road, Varthur, Bengaluru, Karnataka 560087",
        "pitch": "a garden-led community of large 4 BHK homes beside Varthur Lake, close to Whitefield and the Outer Ring Road tech corridor",
        "units": [("4 BHK Garden Classic", "about 3,000 sq ft saleable area with a private garden", "₹3.2 Crore onwards")],
        "possession": "December 2027", "land": "6 acres, 4 towers, about 80% open space",
        "amenities": "clubhouse, temperature-controlled swimming pool, gymnasium, lakeside jogging track, yoga deck, children's play area, indoor games room, co-working lounge, EV charging and 24/7 gated security",
        "places": {
            "International schools": [
                ("Greenwood High International School", "IB, IGCSE and ICSE curriculum, Sarjapur Road", 4, 12),
                ("Inventure Academy", "IGCSE and ICSE curriculum, Whitefield–Sarjapur Road", 8, 22),
                ("The International School Bangalore (TISB)", "IB and IGCSE curriculum, Whitefield–Sarjapur Road", 9, 25),
                ("Gopalan International School", "IGCSE and CBSE curriculum, Whitefield", 9, 25),
            ],
            "Other schools": [("Delhi Public School, Whitefield", "CBSE curriculum", 5, 15)],
            "Hospitals": [
                ("Motherhood Hospital, Sarjapur Road", "maternity and paediatrics", 7, 20),
                ("Sakra World Hospital, Bellandur", "multi-speciality, 24/7 emergency", 9, 25),
                ("Manipal Hospital, Whitefield", "multi-speciality, 24/7 emergency", 9, 25),
            ],
            "Metro and rail": [
                ("Whitefield (Kadugodi) Metro Station", "Purple Line", 8, 22),
                ("Whitefield Railway Station", "suburban and intercity trains", 9, 25),
            ],
            "IT parks and offices": [
                ("Embassy Tech Village, Outer Ring Road", "IT park", 7, 20),
                ("RMZ Ecoworld, Bellandur", "IT park", 9, 25),
                ("ITPL (International Tech Park), Whitefield", "IT park", 10, 28),
            ],
            "Malls and shopping": [
                ("Nexus Whitefield", "shopping mall", 10, 28),
                ("VR Bengaluru, Whitefield Road", "shopping mall", 12, 32),
                ("Phoenix Marketcity, Whitefield Road", "shopping mall", 13, 35),
            ],
            "Airport": [("Kempegowda International Airport", "via Hoskote–airport road", 48, 75)],
            "Parks and leisure": [("Varthur Lake", "lakefront walking area", 1, 3)],
        },
    },
    {
        "name": "Yalahanka Yard", "city": "Bengaluru", "locality": "Yelahanka, North Bengaluru",
        "address": "Yelahanka New Town, Bengaluru, Karnataka 560064",
        "pitch": "spacious 5 BHK residences in North Bengaluru, about 25 minutes from the airport",
        "units": [("5 BHK", "about 2,000 sq ft carpet area", "₹3.8 Crore onwards")],
        "possession": "June 2027", "land": "5 acres, 3 towers",
        "amenities": "clubhouse, swimming pool, gymnasium, squash court, landscaped central park, jogging track, children's play area, party hall, EV charging and 24/7 gated security",
        "places": {
            "International schools": [
                ("Mallya Aditi International School", "IGCSE and ISC curriculum, Yelahanka New Town", 2.5, 8),
                ("Canadian International School", "IB curriculum, Yelahanka", 3, 10),
                ("Stonehill International School", "IB curriculum, Tarahunise", 12, 25),
            ],
            "Other schools": [
                ("Vidyashilp Academy", "ICSE curriculum, Yelahanka", 4, 12),
                ("Delhi Public School, Bangalore North", "CBSE curriculum", 7, 18),
            ],
            "Hospitals": [
                ("Sparsh Hospital, Yelahanka", "multi-speciality, 24/7 emergency", 3, 10),
                ("Cytecare Cancer Hospitals, Yelahanka", "cancer care", 5, 15),
                ("Aster CMI Hospital, Hebbal", "multi-speciality, 24/7 emergency", 10, 25),
            ],
            "Metro and rail": [
                ("Yelahanka Junction", "railway station", 2, 7),
                ("Airport Metro (Blue Line) along Bellary Road", "under construction; nearest planned station about 4 km away", 4, 12),
            ],
            "IT parks and offices": [
                ("Kirloskar Business Park, Hebbal", "offices", 9, 22),
                ("Manyata Embassy Business Park", "IT park", 11, 28),
                ("KIADB Aerospace Park", "aerospace and IT SEZ", 12, 20),
            ],
            "Malls and shopping": [
                ("Phoenix Mall of Asia, Byatarayanapura", "shopping mall", 8, 20),
                ("Esteem Mall, Hebbal", "shopping mall", 10, 25),
            ],
            "Airport": [("Kempegowda International Airport", "via Bellary Road (NH 44)", 18, 25)],
            "Parks and leisure": [("Puttenahalli Lake Bird Sanctuary", "lake and bird sanctuary", 3, 10)],
        },
    },
    {
        "name": "Nikoo Homes", "city": "Bengaluru", "locality": "Rajajinagar / Subramanyanagar, West Bengaluru",
        "address": "1st Cross Road, Milk Colony, Subramanyanagar 2nd Stage, Rajajinagar, Bengaluru, Karnataka 560055",
        "pitch": "well-connected family homes in established West Bengaluru, a short walk from the Green Line metro",
        "units": [
            ("2 BHK + Family", "about 3,000 sq ft saleable area with an extra family room", "₹1.9 Crore onwards"),
            ("3 BHK Canopy", "about 3,000 sq ft saleable area with a canopy terrace", "₹2.6 Crore onwards"),
        ],
        "possession": "March 2027", "land": "4 acres, 3 towers",
        "amenities": "rooftop infinity pool, clubhouse, gymnasium, badminton court, children's play area, senior citizens' garden, amphitheatre, library lounge, EV charging and 24/7 gated security",
        "places": {
            "International schools": [
                ("Canadian International School, Yelahanka", "IB curriculum; the nearest IB school to Nikoo Homes", 18, 40),
            ],
            "Other schools": [
                ("National Public School, Rajajinagar", "CBSE curriculum", 2, 7),
                ("Cluny Convent High School, Malleswaram", "ICSE curriculum", 4, 12),
                ("Kendriya Vidyalaya, Malleswaram", "CBSE curriculum", 4, 12),
            ],
            "Hospitals": [
                ("Manipal Hospital, Malleswaram", "multi-speciality, 24/7 emergency", 4, 12),
                ("Manipal Hospital, Yeshwanthpur", "multi-speciality, 24/7 emergency", 4, 12),
                ("M.S. Ramaiah Memorial Hospital", "multi-speciality teaching hospital", 6, 18),
            ],
            "Metro and rail": [
                ("Mahalakshmi Metro Station", "Green Line", 1.2, 4),
                ("Rajajinagar Metro Station", "Green Line", 1.5, 5),
                ("Yeshwanthpur Junction", "railway station", 3.5, 12),
            ],
            "IT parks and offices": [
                ("World Trade Center Bengaluru, Brigade Gateway", "offices", 2.5, 8),
                ("Peenya Industrial Area", "industrial and offices", 6, 18),
                ("MG Road central business district", "offices", 9, 30),
            ],
            "Malls and shopping": [
                ("Orion Mall, Brigade Gateway", "shopping mall", 2.5, 8),
                ("Lulu Mall, Rajajinagar", "shopping mall", 4, 12),
                ("Mantri Square Mall, Malleswaram", "shopping mall", 4, 12),
            ],
            "Airport": [("Kempegowda International Airport", "via Bellary Road (NH 44)", 35, 60)],
            "Parks and leisure": [
                ("ISKCON Temple, Rajajinagar", "temple and cultural centre", 2, 7),
                ("Sankey Tank", "lake and walking track", 5, 15),
            ],
        },
    },
    {
        "name": "Banjara Beam", "city": "Hyderabad", "locality": "Banjara Hills, Central Hyderabad",
        "address": "Road No. 12, Banjara Hills, Hyderabad, Telangana 500034",
        "pitch": "premium 4 BHK homes in Hyderabad's most prestigious address, minutes from KBR National Park",
        "units": [("4 BHK Classic", "about 2,000 sq ft saleable area", "₹4.5 Crore onwards")],
        "possession": "September 2027", "land": "3 acres, 2 towers",
        "amenities": "sky lounge, infinity pool, spa and sauna, gymnasium, private theatre, business centre, landscaped podium garden, children's play area, valet parking and 24/7 gated security",
        "places": {
            "International schools": [
                ("CHIREC International School, Kondapur", "IB and Cambridge curriculum", 11, 30),
                ("Oakridge International School, Gachibowli", "IB and Cambridge curriculum", 13, 35),
            ],
            "Other schools": [
                ("Meridian School, Banjara Hills", "CBSE curriculum", 1.5, 5),
                ("Jubilee Hills Public School", "CBSE curriculum", 3, 10),
                ("CHIREC Public School, Jubilee Hills", "CBSE curriculum", 4, 12),
                ("Hyderabad Public School, Begumpet", "ICSE curriculum", 6, 18),
            ],
            "Hospitals": [
                ("CARE Hospitals, Banjara Hills", "multi-speciality, 24/7 emergency", 1.5, 5),
                ("Star Hospitals, Banjara Hills", "multi-speciality", 2, 7),
                ("Apollo Hospitals, Jubilee Hills", "multi-speciality, 24/7 emergency", 3.5, 12),
            ],
            "Metro and rail": [
                ("Panjagutta Metro Station", "Red Line", 2.5, 8),
                ("Irrum Manzil Metro Station", "Red Line", 3, 10),
                ("Road No. 5 Jubilee Hills Metro Station", "Blue Line", 3.5, 12),
            ],
            "IT parks and offices": [
                ("HITEC City", "IT hub", 10, 30),
                ("Raheja Mindspace, Madhapur", "IT park", 10, 30),
                ("Financial District, Nanakramguda", "IT and offices", 17, 40),
            ],
            "Malls and shopping": [
                ("City Centre Mall, Banjara Hills", "shopping mall", 1, 4),
                ("GVK One Mall", "shopping mall", 1.5, 5),
                ("Inorbit Mall, Cyberabad", "shopping mall", 9, 28),
            ],
            "Airport": [("Rajiv Gandhi International Airport", "via PV Narasimha Rao Expressway", 32, 45)],
            "Parks and leisure": [
                ("KBR National Park", "nature reserve and walking track", 2, 7),
                ("Hussain Sagar Lake", "lakefront", 5, 18),
            ],
        },
    },
    {
        "name": "Miyapur Manor", "city": "Hyderabad", "locality": "Miyapur, West Hyderabad",
        "address": "Miyapur Main Road, Miyapur, Hyderabad, Telangana 500049",
        "pitch": "large 4.5 BHK homes a short walk from Miyapur Metro, with quick access to HITEC City and top international schools in Bachupally",
        "units": [("4.5 BHK", "about 2,000 sq ft carpet area with a study", "₹2.4 Crore onwards")],
        "possession": "March 2028", "land": "7 acres, 5 towers",
        "amenities": "clubhouse, swimming pool, gymnasium, tennis court, cricket practice net, jogging track, children's play area, banquet hall, EV charging and 24/7 gated security",
        "places": {
            "International schools": [
                ("Oakridge International School, Bachupally", "IB, Cambridge and CBSE curriculum", 6, 15),
                ("Silver Oaks International School, Bachupally", "IB and Cambridge curriculum", 6, 15),
                ("Kennedy High The Global School, Bachupally", "IB and Cambridge curriculum", 7, 18),
                ("CHIREC International School, Kondapur", "IB and Cambridge curriculum", 9, 22),
                ("Meru International School, Tellapur", "IB and Cambridge curriculum", 10, 25),
            ],
            "Hospitals": [
                ("SLG Hospitals, Nizampet", "multi-speciality, 24/7 emergency", 6, 15),
                ("Citizens Specialty Hospital, Nallagandla", "multi-speciality, 24/7 emergency", 8, 20),
                ("AIG Hospitals, Gachibowli", "multi-speciality", 14, 30),
            ],
            "Metro and rail": [
                ("Miyapur Metro Station", "Red Line terminus", 1, 4),
                ("JNTU College Metro Station", "Red Line", 3, 10),
                ("Lingampally Railway Station", "MMTS and intercity trains", 6, 15),
            ],
            "IT parks and offices": [
                ("Kondapur IT corridor", "IT offices", 8, 20),
                ("HITEC City", "IT hub", 11, 28),
                ("Raheja Mindspace, Madhapur", "IT park", 12, 30),
            ],
            "Malls and shopping": [
                ("GSM Mall, Madinaguda", "shopping mall", 2, 7),
                ("Sarath City Capital Mall, Kondapur", "shopping mall", 9, 22),
                ("Inorbit Mall, Cyberabad", "shopping mall", 12, 30),
            ],
            "Airport": [("Rajiv Gandhi International Airport", "via Outer Ring Road", 50, 65)],
        },
    },
    {
        "name": "Saket Square", "city": "Gurugram", "locality": "Golf Course Extension Road, Gurugram",
        "address": "Sector 65, Golf Course Extension Road, Gurugram, Haryana 122102",
        "pitch": "4 BHK garden residences on Golf Course Extension Road, Gurugram's fastest-growing luxury corridor",
        "units": [("4 BHK Garden Classic", "about 3,000 sq ft saleable area with a private garden", "₹5.5 Crore onwards")],
        "possession": "December 2027", "land": "8 acres, 4 towers",
        "amenities": "grand clubhouse, heated swimming pool, spa, gymnasium, tennis and squash courts, mini golf putting green, children's play area, pet park, concierge desk and 24/7 gated security",
        "places": {
            "International schools": [
                ("Heritage Xperiential Learning School, Sector 62", "IB and CBSE curriculum", 3, 8),
                ("Scottish High International School, Sector 57", "IB and Cambridge curriculum", 4, 12),
                ("Pathways School Gurgaon, Baliawas", "IB curriculum", 10, 22),
                ("The Shri Ram School, Aravali", "IB and ICSE curriculum", 14, 30),
            ],
            "Other schools": [
                ("Lotus Valley International School, Sector 50", "CBSE curriculum", 6, 15),
                ("Delhi Public School, Sector 45", "CBSE curriculum", 7, 18),
            ],
            "Hospitals": [
                ("Artemis Hospital, Sector 51", "multi-speciality, 24/7 emergency", 6, 15),
                ("Fortis Memorial Research Institute, Sector 44", "multi-speciality, 24/7 emergency", 9, 22),
                ("Medanta – The Medicity, Sector 38", "multi-speciality, 24/7 emergency", 10, 25),
            ],
            "Metro and rail": [
                ("Sector 55-56 Rapid Metro Station", "Rapid Metro Gurugram", 5, 12),
                ("Millennium City Centre Gurugram Metro Station", "Yellow Line", 9, 22),
            ],
            "IT parks and offices": [
                ("Golf Course Road office cluster", "offices", 5, 12),
                ("Sohna Road business district", "offices", 6, 15),
                ("DLF Cyber City and CyberHub", "offices", 13, 30),
            ],
            "Malls and shopping": [
                ("Worldmark 65", "retail and dining", 0.5, 2),
                ("M3M Urbana", "retail and dining", 1, 3),
                ("Ambience Mall, Gurugram", "shopping mall", 15, 35),
            ],
            "Airport": [("Indira Gandhi International Airport, Delhi", "via NH 48", 25, 40)],
            "Parks and leisure": [
                ("DLF Golf and Country Club", "golf course", 9, 20),
                ("Aravalli Biodiversity Park", "nature park", 12, 28),
            ],
        },
    },
]

CSS = """
body{font-family:-apple-system,Helvetica,Arial,sans-serif;color:#1a1a1a;font-size:11pt;line-height:1.5;margin:0}
h1{font-size:20pt;margin:0 0 4px} h2{font-size:13pt;margin:22px 0 6px;border-bottom:1px solid #c9a96e;padding-bottom:3px}
.sub{color:#666;margin:0 0 14px} p{margin:6px 0} table{border-collapse:collapse;width:100%;margin:6px 0 4px;font-size:10pt}
th,td{border:1px solid #ddd;padding:5px 7px;text-align:left;vertical-align:top} th{background:#f5efe4}
.note{color:#666;font-size:9pt;margin-top:24px}
"""


def e(s):
    return html.escape(str(s))


def km(d):
    return f"{d:g} km"


def place_sentence(p, cat, name, detail, dist, mins):
    singular = {
        "International schools": "international school", "Other schools": "school", "Hospitals": "hospital",
        "Metro and rail": "transit option", "IT parks and offices": "business hub", "Malls and shopping": "shopping destination",
        "Airport": "airport", "Parks and leisure": "leisure spot",
    }[cat]
    return (f"{p['name']} ({p['city']}) is {km(dist)} from {name}, about {mins} minutes by car. "
            f"{name} is a {singular} ({detail}).")


def page(title, subtitle, body):
    return (f"<!doctype html><html><head><meta charset='utf-8'><title>{e(title)}</title><style>{CSS}</style></head>"
            f"<body><h1>{e(title)}</h1><p class='sub'>{e(subtitle)}</p>{body}"
            f"<p class='note'>Distances are approximate road distances from the project site; drive times are typical "
            f"off-peak estimates. For live availability, exact pricing and site visits, contact the WD Elite Residences "
            f"concierge on {CONTACT}.</p></body></html>")


def project_doc(p):
    b = [f"<h2>Overview of {e(p['name'])}</h2>",
         f"<p>{e(p['name'])} is a WD Elite Residences project in {e(p['locality'])}, {e(p['city'])}. "
         f"It is {e(p['pitch'])}. The project spans {e(p['land'])}.</p>",
         f"<p>Address of {e(p['name'])}: {e(p['address'])}.</p>",
         f"<p>Expected possession for {e(p['name'])}: {e(p['possession'])}.</p>",
         f"<h2>Unit types and prices at {e(p['name'])}</h2>",
         "<table><tr><th>Unit type</th><th>Size</th><th>Starting price</th></tr>"]
    b += [f"<tr><td>{e(u)}</td><td>{e(s)}</td><td>{e(pr)}</td></tr>" for u, s, pr in p["units"]]
    b.append("</table>")
    b += [f"<p>{e(p['name'])} offers {e(u)} homes of {e(s)}, priced from {e(pr)}.</p>" for u, s, pr in p["units"]]
    b += [f"<h2>Amenities at {e(p['name'])}</h2>",
          f"<p>Amenities at {e(p['name'])} include {e(p['amenities'])}.</p>"]

    for cat, items in p["places"].items():
        b.append(f"<h2>{e(cat)} near {e(p['name'])}, {e(p['city'])}</h2>")
        b.append("<table><tr><th>Place</th><th>Details</th><th>Distance</th><th>Drive time</th></tr>")
        b += [f"<tr><td>{e(n)}</td><td>{e(d)}</td><td>{km(k)}</td><td>about {m} min</td></tr>" for n, d, k, m in items]
        b.append("</table>")
        b += [f"<p>{e(place_sentence(p, cat, n, d, k, m))}</p>" for n, d, k, m in items]

    intl = sorted(p["places"].get("International schools", []), key=lambda x: x[2])
    b.append(f"<h2>Frequently asked questions about {e(p['name'])}</h2>")
    if intl:
        n, d, k, m = intl[0]
        close = "within 5 km" if k <= 5 else "not within 5 km"
        b.append(f"<p><b>Is {e(p['name'])} near an international school?</b> The nearest international school to "
                 f"{e(p['name'])} is {e(n)} ({e(d)}), {km(k)} away (about {m} minutes). {e(p['name'])} is {close} of an "
                 f"international school. In total, {len(intl)} international school(s) are listed near {e(p['name'])}.</p>")
    hosp = min(p["places"]["Hospitals"], key=lambda x: x[2])
    b.append(f"<p><b>What is the nearest hospital to {e(p['name'])}?</b> {e(hosp[0])}, {km(hosp[2])} away "
             f"(about {hosp[3]} minutes).</p>")
    metro = min(p["places"]["Metro and rail"], key=lambda x: x[2])
    b.append(f"<p><b>How far is the nearest metro or train station from {e(p['name'])}?</b> {e(metro[0])} "
             f"({e(metro[1])}) is {km(metro[2])} away.</p>")
    air = p["places"]["Airport"][0]
    b.append(f"<p><b>How far is {e(p['name'])} from the airport?</b> {e(air[0])} is {km(air[2])} away, about "
             f"{air[3]} minutes {e(air[1])}.</p>")
    it = min(p["places"]["IT parks and offices"], key=lambda x: x[2])
    b.append(f"<p><b>Which offices or IT parks are close to {e(p['name'])}?</b> The closest is {e(it[0])} at "
             f"{km(it[2])}; see the IT parks table above for more.</p>")
    return page(f"{p['name']} – Project and Neighbourhood Guide",
                f"WD Elite Residences · {p['locality']}, {p['city']}", "".join(b))


def portfolio_doc():
    b = ["<h2>All WD Elite Residences projects</h2>",
         "<table><tr><th>Project</th><th>City</th><th>Locality</th><th>Unit types</th><th>Starting price</th><th>Possession</th></tr>"]
    for p in PROJECTS:
        b.append(f"<tr><td>{e(p['name'])}</td><td>{e(p['city'])}</td><td>{e(p['locality'])}</td>"
                 f"<td>{e(', '.join(u[0] for u in p['units']))}</td><td>{e(min(u[2] for u in p['units']))}</td>"
                 f"<td>{e(p['possession'])}</td></tr>")
    b.append("</table>")
    by_city = {}
    for p in PROJECTS:
        by_city.setdefault(p["city"], []).append(p["name"])
    b.append(f"<p>WD Elite Residences has {len(PROJECTS)} residential projects in {len(by_city)} cities: "
             + "; ".join(f"{c}: {', '.join(n)}" for c, n in by_city.items()) + ".</p>")

    def ranking(cat, title, question):
        rows = []
        for p in PROJECTS:
            items = p["places"].get(cat, [])
            if items:
                n, d, k, m = min(items, key=lambda x: x[2])
                rows.append((k, p, n, d, m))
        rows.sort(key=lambda r: r[0])
        out = [f"<h2>{e(title)}</h2>", f"<p>{e(question)} Ranked from closest to farthest:</p>",
               "<table><tr><th>Project</th><th>City</th><th>Nearest</th><th>Distance</th></tr>"]
        out += [f"<tr><td>{e(p['name'])}</td><td>{e(p['city'])}</td><td>{e(n)} ({e(d)})</td><td>{km(k)}</td></tr>"
                for k, p, n, d, m in rows]
        out.append("</table>")
        out += [f"<p>{e(p['name'])} in {e(p['city'])}: nearest is {e(n)}, {km(k)} away (about {m} minutes).</p>"
                for k, p, n, d, m in rows]
        return out

    b += ranking("International schools", "Projects near international schools (IB, IGCSE, Cambridge)",
                 "Which WD Elite project is closest to an international school?")
    near = [p["name"] for p in PROJECTS if any(x[2] <= 5 for x in p["places"].get("International schools", []))]
    b.append(f"<p>Projects with an international school within 5 km: {e(', '.join(near))}.</p>")
    b += ranking("Hospitals", "Projects near hospitals", "Which WD Elite project is closest to a hospital?")
    b += ranking("Metro and rail", "Projects near metro and train stations",
                 "Which WD Elite project is closest to a metro or railway station?")
    b += ranking("IT parks and offices", "Projects near IT parks and offices",
                 "Which WD Elite project is best for a short office commute?")
    b += ranking("Airport", "Projects by distance to the airport", "Which WD Elite project is closest to the airport?")
    return page("WD Elite Residences – Portfolio Neighbourhood Guide",
                "Compare all projects by schools, hospitals, metro, offices and airport", "".join(b))


def faq_doc():
    qa = [
        ("Who is WD Elite Residences?", "WD Elite Residences is the luxury homes brand of WD Residential, with six residential projects across Bengaluru, Hyderabad and Gurugram."),
        ("What payment plans are available?", "WD Elite Residences offers construction-linked payment plans, down-payment plans with a discount, and assistance with home loans from leading banks such as HDFC Bank, SBI, ICICI Bank and Axis Bank."),
        ("Are the projects RERA registered?", "Yes. Every WD Elite Residences project is registered with the state RERA authority (Karnataka RERA, Telangana RERA or Haryana RERA). The concierge can share the RERA number for any project."),
        ("Can NRIs buy a WD Elite home?", "Yes. NRIs can buy WD Elite Residences homes, and the sales team helps with NRE/NRO payments, power of attorney and home loans for NRIs."),
        ("How do I book a site visit?", "Share your name, phone number, email, preferred project and a date and time with the concierge, and a site visit will be scheduled. Site visits are available every day from 10 AM to 6 PM."),
        ("Is parking available?", "Yes. Every home includes covered car parking, with additional visitor parking. Larger homes include two or more car parks."),
        ("What security is provided?", "All projects are gated communities with 24/7 trained security, CCTV surveillance, access-controlled entry and video door phones."),
        ("Are pets allowed?", "Yes. WD Elite Residences communities are pet-friendly, and several projects have a dedicated pet park."),
        ("Are the projects eco-friendly?", "Projects include rainwater harvesting, solar-powered common areas, sewage treatment plants, EV charging points and organic waste converters."),
        ("Can I customise my home?", "Limited customisation of finishes and layouts may be possible depending on the construction stage. Discuss your requirements with the sales team."),
        ("Who do I contact?", f"Call the WD Elite Residences concierge on {CONTACT}, or ask the website chat assistant to arrange a call back."),
    ]
    body = "<h2>Buying a home with WD Elite Residences</h2>" + "".join(
        f"<p><b>{e(q)}</b> {e(a)}</p>" for q, a in qa)
    return page("WD Elite Residences – Buyer FAQ", "Payments, loans, RERA, site visits and policies", body)


def to_pdf(name, content):
    OUT.mkdir(exist_ok=True)
    src = OUT / f"{name}.html"
    src.write_text(content, encoding="utf-8")
    pdf = OUT / f"{name}.pdf"
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={pdf}", src.as_uri()], check=True, capture_output=True)
    src.unlink()
    print("wrote", pdf.name)


if __name__ == "__main__":
    for p in PROJECTS:
        to_pdf("WD_Elite_" + p["name"].replace(" ", "_"), project_doc(p))
    to_pdf("WD_Elite_Portfolio_Neighbourhood_Guide", portfolio_doc())
    to_pdf("WD_Elite_Buyer_FAQ", faq_doc())
