import { base44 } from '@/api/base44Client';
import { format, addDays, subDays, parseISO, startOfWeek, endOfWeek } from 'date-fns';

/**
 * Given a congregation_id and a conversion_date (YYYY-MM-DD string),
 * checks if there's a WeeklyReport covering that date and deletes it.
 * This auto-resolves a "no conversions" report when a convert is registered.
 */
export async function resolveWeeklyReportIfNeeded(congregationId, conversionDateStr) {
  if (!congregationId || !conversionDateStr) return;

  // For a given conversion date, find what reporting week it falls in.
  // Reporting week: Monday to Sunday. We need to check every possible week_start
  // that could cover conversionDateStr.
  // week_start is stored as the Monday of that week (yyyy-MM-dd).
  // conversionDate must be >= week_start and <= week_start + 6 days

  const convDate = parseISO(conversionDateStr);

  // Find Monday of the week containing convDate
  const dayOfWeek = convDate.getDay(); // 0 = Sun
  // Days since Monday: if Sunday (0), it's 6 days after Monday
  const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const monday = new Date(convDate);
  monday.setDate(convDate.getDate() - daysFromMonday);
  monday.setHours(0, 0, 0, 0);
  const weekStartStr = format(monday, 'yyyy-MM-dd');

  // Look for a WeeklyReport for this congregation and this week
  const reports = await base44.entities.WeeklyReport.filter({
    congregation_id: congregationId,
    week_start: weekStartStr,
  });

  for (const report of reports) {
    await base44.entities.WeeklyReport.delete(report.id);
  }
}