# API Entwurf


## Parcels


#### Model

```
Parcel = {
  id: UUID,
  state: "CREATED" | 
         "ACCEPTED" | 
         "IN_TRANSIT" | 
         "OUT_FOR_DELIVERY" | 
         "DELIVERED" | 
         "DELIVERY_FAILED"
  driver: UUID
  customer: UUID
  origin : Address
  destination Address
  driver: UUID | null
}
```

``` 
Customer = {
  id: UUID
  name: String
  firstName: String
  address: Address
  accountId: UUID
}

Account = {
  
}

```
/parcels	POST	Paket aufgeben	201 + Location	
/parcels  GET   Pakte listen.   200

/parcels/:id  PATCH Partial<Parcel>

```

