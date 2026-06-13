/// Section-count limits for the spinning wheel, defined once and shared by the
/// data layer ([AppDatabase]), the geometry/painter, and the UI so the cap can
/// never drift between them.
library;

/// Fewest sections the wheel can render.
const int wheelMinSections = 2;

/// Most sections the wheel shows at once. The data layer never places more than
/// this many tasks on the wheel, and the painter/geometry never render more.
const int wheelMaxSections = 15;
