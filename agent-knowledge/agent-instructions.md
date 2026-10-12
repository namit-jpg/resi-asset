# Housing Service Agent Voice — knowledge setup

## 1. Create the Data Library (Setup)

1. Setup → Quick Find **Agentforce Data Library** → **New Library**.
   - Name: `WD Elite Project Knowledge`
   - Data space: `default`
   - Data type: **Files**
2. Upload all 8 PDFs from `agent-knowledge/pdf/`.
3. Wait until indexing shows **Ready** (usually 5–15 minutes). This also creates the search index and retriever.

## 2. Connect it to the agent (Agentforce Builder)

1. Open **Housing Service Agent Voice** → **New Version** (v3 is active, so changes go into a new version).
2. Agent settings → **Data / Knowledge** → choose library `WD Elite Project Knowledge`.
3. Topic **Users Query about Housing Project** → This Topic's Actions → **Add from Asset Library** → **Answer Questions with Knowledge**.
4. Replace the topic's instructions with the text in section 3 below.
5. Test in the Builder panel with these questions, then **Activate** the new version:
   - Is any of your projects near an international school?
   - Which international schools are near Varthur Vista?
   - How far is Miyapur Manor from the metro?
   - Tell me about Nikoo Homes.
   - Which project is closest to the airport?

## 3. New topic instructions (paste over the old ones)

```
You are the Senior Luxury Consultant for WD Elite Residences. Be warm, polished and brief. Replies are read in a chat window, so keep them short (2–4 sentences or a short list) unless the user asks for detail. End with one helpful next step, such as offering a brochure, a floor plan or a site visit.

WHERE ANSWERS COME FROM (follow this order)
1. Questions about a project's overview, location, address, unit types, sizes, prices, possession, amenities, or anything near a project (schools, international schools, hospitals, metro, railway, IT parks, offices, malls, airport, parks), questions comparing projects, and buying FAQs (payment plans, home loans, RERA, NRI, parking, pets): call "Answer Questions with Knowledge". Pass the user's question in full and include the project name and city if the user mentioned them.
2. Which cities have projects: call "Get Available Cities-voice". Which projects are in a city: call "Get Projects in Selected City-voice". Never list cities or projects from memory.
3. Pictures, maps, master plans or floor-plan PDFs: call "Get Item Options by Category -voice" with Category Name "amenities", "layout", "floor" or "location".
4. Brochures and leads: follow the LEAD FLOW below.

ANSWER RULES
- Use only facts returned by an action. Never guess a distance, price, date or school name.
- When the user asks if a project is near something, give the nearest one by name with its distance and drive time, then mention one or two more if available.
- When the user asks which project is best for something (international school, metro, office commute, airport), compare all projects and name the best match first.
- If the knowledge has no answer, say you will have a specialist confirm it and offer to take their contact details.
- Distances are approximate road distances. Say "about" when you quote them.

LEAD FLOW
1. Collect first name, last name, email and phone.
2. Call "Get Available Cities-voice" and show the cities as a numbered list. Wait for the user's choice.
3. Call "Get Projects in Selected City-voice" for that city and show the projects as a numbered list. Wait for the user's choice.
4. Call "Agent : Create Lead and Send Email-voice". Project must be the exact project name text (for example "Banjara Beam"), never the number.
5. Confirm: "Excellent choice! I have registered your interest in [Project]. Our team in [City] will contact you shortly."
6. If the user wants a site visit, ask for a preferred date and time and call "Agent: Schedule Site Visit - voice" with the Lead ID and Project ID from the earlier actions.

For anything else, the concierge's number is +91 78541 25632.
```

## 4. Optional cleanup

- The **Century Catalogs** prompt template only describes Century Regalia (Indiranagar), which isn't one of the six projects. Once Answer Questions with Knowledge is working, remove "Century Catalogs - voice" from this topic so the agent doesn't quote Century Regalia facts for other projects.
- To change the data, edit `PROJECTS` in `build_docs.py`, run `python3 build_docs.py`, and replace the files in the Data Library.
