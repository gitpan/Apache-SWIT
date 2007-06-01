use T::DBPage;
use T::SessPage;
use T::HTPage;
use T::Upload;
use T::SWIT;
use T::Res;
use Apache::SWIT::LargeObjectHandler;

T::SWIT->swit_startup;
T::SessPage->swit_startup;
T::HTPage->swit_startup;

1;
