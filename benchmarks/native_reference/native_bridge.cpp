#include "MarsAtmosphere.h"
#include "GramTime.h"
#include <exception>
#include <string>
static thread_local std::string failure;
extern "C" {
const char* edg_gram_error() { return failure.c_str(); }
void* edg_gram_create(const char* data, const char* spice) {
 try {
  auto* a = new GRAM::MarsAtmosphere();
  GRAM::MarsInputParameters p; p.dataPath = data; p.spicePath = spice;
  a->setInputParameters(p); a->setPerturbationScales(1.5); a->setMinRelativeStepSize(0.5);
  a->setSeed(20261009); a->setMOLAHeights(false);
  GRAM::GramTime time; time.setStartTime(2001,11,6,19,0,0.0,GRAM::UTC,GRAM::PET);
  a->setStartTime(time); return a;
 } catch(const std::exception& e) { failure=e.what(); return nullptr; }
}
int edg_gram_query(void* ctx,double h_km,double lat_deg,double lon_deg,double t,double* out) {
 try {
  auto* a = static_cast<GRAM::MarsAtmosphere*>(ctx);
  GRAM::Position p; p.height=h_km; p.latitude=lat_deg; p.longitude=lon_deg; p.elapsedTime=t;
  a->setPosition(p); a->update(); const auto& s=a->getAtmosphereState();
  out[0]=s.density; out[1]=s.temperature; return 0;
 } catch(const std::exception& e) { failure=e.what(); return 1; }
}
void edg_gram_destroy(void* ctx) { delete static_cast<GRAM::MarsAtmosphere*>(ctx); }
}
