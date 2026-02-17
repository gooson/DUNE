# Data Integrity Guardian Memory

## Project Context
- Health & Fitness App with HRV/RHR analysis
- SwiftData + CloudKit backend (bad data spreads across all devices)
- Critical: Input validation at entry point prevents CloudKit propagation

## Key Patterns Learned

### SwiftData Relationship Integrity
- @Relationship(deleteRule: .cascade) ensures child cleanup
- Inverse relationships must be bidirectional for consistency
- String-based enum storage requires fallback on decode (compactMap, ??)

### Validation Rules from Correction Log
- HealthKit value ranges: Weight(0-500kg), BMI(0-100), HR(20-300bpm), HRV(0-500ms)
- String input limits: Memo max 500 chars
- User input: Always validate before SwiftData insert
- Consistent validation across all query paths for same data

### Common Data Integrity Risks
1. Missing validation on optional fields (weight can be empty but if present must be valid)
2. String-to-number conversion without bounds checking
3. Relationship cascade without testing orphan cleanup
4. Enum rawValue storage without decode fallback
5. Math operations without NaN/Infinite checks

## Review Checklist
- [ ] All user inputs have min/max range validation
- [ ] String-to-number conversions check bounds
- [ ] Optional inputs: empty OK, but if present must validate
- [ ] Math results checked for isNaN, isInfinite
- [ ] Relationships have proper deleteRule
- [ ] Enum decoding has fallback (compactMap or ?? default)
- [ ] isSaving flag on all mutation methods
- [ ] CloudKit implications considered (bad data spreads)
