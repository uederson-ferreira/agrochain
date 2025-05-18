from pydantic import BaseModel
from typing import List

class ClimateParameter(BaseModel):
    parameterType: str
    thresholdValue: int
    periodInDays: int
    triggerAbove: bool
    payoutPercentage: int    
class CreatePolicyRequest(BaseModel):
    farmer: str
    coverageAmount: int
    startDate: int
    endDate: int
    region: str
    cropType: str
    parameters: List[ClimateParameter]
    zkProofHash: str  # ✅ NOVO CAMPO

class ActivatePolicyRequest(BaseModel):
    premium: int

class ClimateDataRequest(BaseModel):
    parameterType: str
    region: str

class AddCapitalRequest(BaseModel):
    amount: int

class CreateProposalRequest(BaseModel):
    description: str
    targetContract: str
    callData: str

class VoteProposalRequest(BaseModel):
    support: bool

class AddRegionRequest(BaseModel):
    region: str

class AddCropRequest(BaseModel):
    crop: str

class SetOracleRequest(BaseModel):
    region: str
    oracleAddress: str