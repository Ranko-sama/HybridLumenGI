// Only compiled for the four deterministic test queries. No product-buffer writes.
RWStructuredBuffer<float4> _ISC_Records;
static uint ISC_Lane;
void ISW(uint row,float4 value){_ISC_Records[ISC_Lane*80u+row]=value;}
