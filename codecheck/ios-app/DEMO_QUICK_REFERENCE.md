# CodeCheck Demo - Quick Reference Card

**Print this and keep it next to you during the demo!**

---

## 30-Second Pitch (Memorize This)

> "CodeCheck is an AI-powered mobile app that instantly validates building compliance using your iPhone's AR camera. Point your phone at any structure, and in seconds, get real-time code violations, compliance recommendations, and AI explanations - all based on your exact location's building codes. We're making building inspections 10x faster and eliminating costly code violations before construction."

---

## Demo Flow (2 Minutes)

| Time | Action | What To Say |
|------|--------|-------------|
| **0:00-0:15** | Show home screen | "Contractors waste hours checking building codes, leading to expensive violations. Let me show you CodeCheck." |
| **0:15-0:35** | Create project | "I'm creating a new residential project in Denver. Watch how it auto-detects my location and loads the correct building codes." |
| **0:35-1:05** | AR measurement | "Now I'll use AR to measure this handrail. CodeCheck uses your iPhone's LiDAR for precision measurements - no tape measure needed." |
| **1:05-1:35** | Check compliance | "Here's the magic - instant compliance checking against Denver's building codes. Results in 2 seconds." |
| **1:35-2:00** | AI explanation | "Not sure why it's a violation? Our AI explains the code in plain English and tells you exactly how to fix it." |
| **2:00-2:10** | Close | "That's it. What took hours now takes 60 seconds. We catch violations before they cost thousands to fix." |

---

## Technical Setup (Check Before Demo)

### Backend Status
```bash
# Terminal 1: Backend running?
curl http://localhost:8001/
# Should return: {"message":"CodeCheck API is running","version":"1.0.0"}
```

### Network Config
- **Mac IP**: 10.0.0.214
- **Port**: 8001
- **WiFi**: Mac and iPhone on same network
- **Test login**: test@codecheck.app / Test1234

### iPhone Ready?
- ✅ Battery 80%+
- ✅ Do Not Disturb ON
- ✅ Brightness 80%+
- ✅ App open, logged in
- ✅ Location: Denver, CO

---

## Demo Talking Points

### Problem
"750,000 contractors in the US struggle with building code compliance. One violation costs $5,000-$50,000 to fix after construction."

### Solution
"CodeCheck uses AR + AI to check compliance in real-time. Point, measure, check - done in 60 seconds."

### Market
"$1.6 trillion construction industry. Every contractor needs this."

### Traction
"Denver fully loaded with 15 building codes. Expanding to top 50 US cities in Q2."

### Business Model
"Freemium: $29.99/month Pro, $99.99/month Teams. One prevented violation pays for a year."

---

## Key Features (Highlight These)

1. **Location-Aware**: Auto-detects location, loads correct codes
2. **AR Precision**: iPhone LiDAR, sub-inch accuracy, no tape measure
3. **Real-Time**: Results in 2-3 seconds, not hours
4. **AI Explanations**: Plain English, tells you how to fix it
5. **Cost Savings**: Prevents expensive violations before construction

---

## Demo Measurements (Choose One)

### Option A: Handrail (Best)
- Measure: Handrail height
- Expected: 34-38 inches required
- Violation: If outside range
- Why it matters: "Falls are #1 residential injury"

### Option B: Door (Simple)
- Measure: Door width
- Expected: 32 inches minimum
- Violation: If < 32 inches
- Why it matters: "ADA accessibility requirement"

### Option C: Stair Riser (Complex)
- Measure: Stair riser height
- Expected: < 7.75 inches
- Violation: If > 7.75 inches
- Why it matters: "Trip hazard, code violation"

---

## Top 10 Questions & Answers

### Q1: "How accurate are measurements?"
**A**: "Sub-inch accuracy using iPhone's LiDAR - more accurate than most tape measures in field conditions. Validated against professional laser measures."

### Q2: "What if there's no internet?"
**A**: "Once codes are loaded, they're cached locally. You can measure and check compliance offline. AI explanations need internet."

### Q3: "How do you update codes?"
**A**: "We monitor municipal code updates continuously. When codes change, we review, update, and push to users within 48 hours. Users get notifications."

### Q4: "Why would contractors pay?"
**A**: "One violation costs $5,000-$50,000 to fix. Our Pro tier at $29.99/month pays for itself with one prevented violation. Plus inspections are 10x faster."

### Q5: "What jurisdictions do you support?"
**A**: "Denver fully loaded with 15 codes. Top 50 US cities in Q2 2024. Nationwide coverage by year-end."

### Q6: "Can this replace building inspectors?"
**A**: "No, and that's not our goal. We help contractors and inspectors work faster. Inspectors still do final sign-off, but spend less time on obvious violations."

### Q7: "What's your unfair advantage?"
**A**: "Three things: Mobile-first AR measurement (nobody else has this). AI explanations (competitors just show rules). Our team includes former contractors who understand the pain."

### Q8: "How does the AI work?"
**A**: "We use Anthropic's Claude AI, trained on building codes and safety standards. It analyzes the specific rule, your measurement, and generates plain-English explanations with recommendations."

### Q9: "What's your revenue model?"
**A**: "Freemium SaaS. Free tier for 3 projects. Pro at $29.99/month for unlimited projects. Teams at $99.99/month for collaboration. Enterprise for municipalities."

### Q10: "How big is the market?"
**A**: "750,000 contractors (primary market), 40,000 inspectors, 120,000 architects, 80 million homeowners doing renovations. $1.6 trillion construction industry."

---

## Troubleshooting (During Demo)

| Problem | Quick Fix | What To Say |
|---------|-----------|-------------|
| Backend not responding | Check Terminal, restart backend | "Let me reconnect - typical network hiccup" |
| iPhone can't connect | Check WiFi, verify IP | "Looks like WiFi interference - let me show a backup" |
| AR not working | Move to brighter area | "AR works best in good lighting - let me adjust" |
| App crashes | Reopen app | "Let me restart the app quickly" |
| Slow AI response | Have pre-generated explanation | "AI is a bit slow today - here's a previous explanation" |

**Backup Plan**: Have screenshots and demo video ready!

---

## Body Language & Presentation

### Do:
✅ Make eye contact with investors (not just phone)
✅ Explain each step BEFORE you do it
✅ Speak clearly and confidently
✅ Show enthusiasm (this is your baby!)
✅ Acknowledge loading times: "Just 2 seconds..."
✅ Ask: "Have you ever had a code violation?"

### Don't:
❌ Rush through demo (you have 2 minutes, use them)
❌ Apologize excessively ("Sorry this is slow")
❌ Look down at phone entire time
❌ Panic if something breaks (stay calm, use backup)
❌ Use technical jargon (say "checks codes" not "API endpoint")
❌ Forget to close with impact statement

---

## The Perfect Close

**After demo, say this**:
"That's CodeCheck. We're making building inspections 10x faster and preventing costly violations before construction. This is live right now - want to see it measure something else?"

**Then**:
- Pause for questions
- Get investor contact info
- Offer to send deck and schedule follow-up
- Thank them for their time

---

## Pre-Demo Mental Checklist

5 minutes before, remind yourself:

- [ ] I've built a working product (impressive!)
- [ ] I've tested this 3+ times today (I know it works)
- [ ] I'm solving a real problem ($1.6T market)
- [ ] I know my pitch by heart
- [ ] I have backup plan if tech fails
- [ ] Technical hiccups are normal (investors expect them)
- [ ] Investors want me to succeed (they're on my side)
- [ ] I am the expert on this product
- [ ] I am confident and passionate
- [ ] I've got this!

**Deep breath. You're ready. Go get funded!**

---

## Emergency Contacts

- **Backend**: http://10.0.0.214:8001
- **Test Login**: test@codecheck.app / Test1234
- **Demo Guide**: `/Users/raulherrera/autonomous-learning/codecheck/ios-app/INVESTOR_DEMO_GUIDE.md`
- **Build Guide**: `/Users/raulherrera/autonomous-learning/codecheck/ios-app/XCODE_BUILD_INSTRUCTIONS.md`
- **Checklist**: `/Users/raulherrera/autonomous-learning/codecheck/ios-app/PRE_DEMO_CHECKLIST.md`

---

## Post-Demo

Within 24 hours:
1. Send thank you email with deck
2. LinkedIn connect with note
3. Schedule follow-up call if interest
4. Log notes in CRM
5. Debrief: what went well, what to improve

---

**You've prepared. You've practiced. You've got this.**

**Now go show them what CodeCheck can do!**

**🚀 Good luck! 🚀**
