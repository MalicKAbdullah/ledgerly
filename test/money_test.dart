import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly/src/core/money/money.dart';

void main() {
  group('Money construction', () {
    test('stores minor units and currency', () {
      const m = Money(1250, 'USD');
      expect(m.minorUnits, 1250);
      expect(m.currency, 'USD');
    });

    test('zero', () {
      const z = Money.zero('EUR');
      expect(z.minorUnits, 0);
      expect(z.isZero, isTrue);
      expect(z.isNegative, isFalse);
    });
  });

  group('Money.parse', () {
    test('parses whole and fractional amounts exactly', () {
      expect(Money.parse('0', 'USD').minorUnits, 0);
      expect(Money.parse('1', 'USD').minorUnits, 100);
      expect(Money.parse('1.5', 'USD').minorUnits, 150);
      expect(Money.parse('1.50', 'USD').minorUnits, 150);
      expect(Money.parse('1234.56', 'USD').minorUnits, 123456);
      expect(Money.parse('.5', 'USD').minorUnits, 50);
      expect(Money.parse('+2.25', 'USD').minorUnits, 225);
    });

    test('accepts thousands separators', () {
      expect(Money.parse('1,234.56', 'USD').minorUnits, 123456);
    });

    test('rounds extra decimals half-up', () {
      expect(Money.parse('1.005', 'USD').minorUnits, 101);
      expect(Money.parse('1.004', 'USD').minorUnits, 100);
      expect(Money.parse('1.0049', 'USD').minorUnits, 100);
      expect(Money.parse('0.999', 'USD').minorUnits, 100);
    });

    test('rounds negatives half-up away from zero', () {
      expect(Money.parse('-1.005', 'USD').minorUnits, -101);
      expect(Money.parse('-1.004', 'USD').minorUnits, -100);
    });

    test('zero-decimal currencies (JPY)', () {
      expect(Money.parse('1234', 'JPY').minorUnits, 1234);
      expect(Money.parse('1234.5', 'JPY').minorUnits, 1235);
      expect(Money.parse('1234.4', 'JPY').minorUnits, 1234);
    });

    test('three-decimal currencies (KWD)', () {
      expect(Money.parse('1.234', 'KWD').minorUnits, 1234);
      expect(Money.parse('1.2345', 'KWD').minorUnits, 1235);
      expect(Money.parse('1.2344', 'KWD').minorUnits, 1234);
    });

    test('rejects malformed input', () {
      for (final bad in ['', 'abc', '1.2.3', '-', '+', '1a', '--1', '1..2']) {
        expect(
          () => Money.parse(bad, 'USD'),
          throwsFormatException,
          reason: 'should reject "$bad"',
        );
      }
    });
  });

  group('Money arithmetic', () {
    test('addition and subtraction', () {
      const a = Money(150, 'USD');
      const b = Money(75, 'USD');
      expect(a + b, const Money(225, 'USD'));
      expect(a - b, const Money(75, 'USD'));
      expect(-a, const Money(-150, 'USD'));
    });

    test('rejects mixed currencies', () {
      const usd = Money(100, 'USD');
      const eur = Money(100, 'EUR');
      expect(() => usd + eur, throwsArgumentError);
      expect(() => usd - eur, throwsArgumentError);
      expect(() => usd.compareTo(eur), throwsArgumentError);
      expect(() => usd > eur, throwsArgumentError);
    });

    test('integer multiplication is exact', () {
      expect(const Money(333, 'USD').times(3), const Money(999, 'USD'));
      expect(const Money(-50, 'USD').times(4), const Money(-200, 'USD'));
    });

    test('clampNonNegative', () {
      expect(
        const Money(-5, 'USD').clampNonNegative(),
        const Money.zero('USD'),
      );
      expect(const Money(5, 'USD').clampNonNegative(), const Money(5, 'USD'));
    });
  });

  group('Money.percentBp rounding (half-up, away from zero)', () {
    test('typical tax rates', () {
      // $10.50 at 7.5% = 0.7875 -> 0.79
      expect(const Money(1050, 'USD').percentBp(750), const Money(79, 'USD'));
      // $100.00 at 20% = exact
      expect(
        const Money(10000, 'USD').percentBp(2000),
        const Money(2000, 'USD'),
      );
    });

    test('exact half rounds up', () {
      // 2 cents at 25% = 0.5 -> 1
      expect(const Money(2, 'USD').percentBp(2500), const Money(1, 'USD'));
      // 6 cents at 25% = 1.5 -> 2
      expect(const Money(6, 'USD').percentBp(2500), const Money(2, 'USD'));
    });

    test('below half rounds down', () {
      // 1 cent at 25% = 0.25 -> 0
      expect(const Money(1, 'USD').percentBp(2500), const Money.zero('USD'));
      // 49 at 1% = 0.49 -> 0
      expect(const Money(49, 'USD').percentBp(100), const Money.zero('USD'));
    });

    test('negative amounts round away from zero', () {
      expect(const Money(-2, 'USD').percentBp(2500), const Money(-1, 'USD'));
      expect(const Money(-1, 'USD').percentBp(2500), const Money.zero('USD'));
    });

    test('zero and 100 percent', () {
      expect(const Money(999, 'USD').percentBp(0), const Money.zero('USD'));
      expect(const Money(999, 'USD').percentBp(10000), const Money(999, 'USD'));
    });
  });

  group('Money.timesQuantityMilli', () {
    test('fractional hours', () {
      // 1.5 h x $100.00
      expect(
        const Money(10000, 'USD').timesQuantityMilli(1500),
        const Money(15000, 'USD'),
      );
      // 0.333 x $1.00 = 0.333 -> 0.33
      expect(
        const Money(100, 'USD').timesQuantityMilli(333),
        const Money(33, 'USD'),
      );
    });

    test('exact half rounds up', () {
      // 0.005 x $1.00 = 0.5 cents -> 1 cent
      expect(
        const Money(100, 'USD').timesQuantityMilli(5),
        const Money(1, 'USD'),
      );
    });

    test('whole quantities are exact', () {
      expect(
        const Money(12345, 'USD').timesQuantityMilli(3000),
        const Money(37035, 'USD'),
      );
    });
  });

  group('Money formatting', () {
    test('USD with grouping', () {
      expect(const Money(123450, 'USD').format(), r'$1,234.50');
      expect(const Money(5, 'USD').format(), r'$0.05');
      expect(const Money(-9950, 'USD').format(), r'-$99.50');
    });

    test('zero-decimal currency', () {
      expect(const Money(1234567, 'JPY').format(), '¥1,234,567');
    });

    test('three-decimal currency keeps 3 digits', () {
      final formatted = const Money(1234, 'KWD').format();
      expect(formatted, endsWith('1.234'));
    });

    test('toDecimalString round-trips through parse', () {
      for (final minor in [0, 1, 99, 100, 12345, -12345, -1]) {
        final money = Money(minor, 'USD');
        expect(
          Money.parse(money.toDecimalString(), 'USD'),
          money,
          reason: 'round trip for $minor',
        );
      }
    });
  });

  group('Money equality and ordering', () {
    test('value equality', () {
      expect(const Money(100, 'USD'), const Money(100, 'USD'));
      expect(const Money(100, 'USD'), isNot(const Money(100, 'EUR')));
      expect(
        const Money(100, 'USD').hashCode,
        const Money(100, 'USD').hashCode,
      );
    });

    test('comparison', () {
      expect(const Money(200, 'USD') > const Money(100, 'USD'), isTrue);
      expect(const Money(50, 'USD') < const Money(100, 'USD'), isTrue);
      expect(const Money(100, 'USD').compareTo(const Money(100, 'USD')), 0);
    });
  });

  group('basis point helpers', () {
    test('tryParseBasisPoints', () {
      expect(tryParseBasisPoints('7.5'), 750);
      expect(tryParseBasisPoints('7.5%'), 750);
      expect(tryParseBasisPoints('0'), 0);
      expect(tryParseBasisPoints(''), 0);
      expect(tryParseBasisPoints('20'), 2000);
      expect(tryParseBasisPoints('7.125'), 713); // rounded half-up
      expect(tryParseBasisPoints('abc'), isNull);
    });

    test('formatBasisPoints', () {
      expect(formatBasisPoints(750), '7.5');
      expect(formatBasisPoints(700), '7');
      expect(formatBasisPoints(725), '7.25');
      expect(formatBasisPoints(0), '0');
      expect(formatBasisPoints(10000), '100');
    });
  });

  group('quantity helpers', () {
    test('tryParseQuantityMilli', () {
      expect(tryParseQuantityMilli('1'), 1000);
      expect(tryParseQuantityMilli('1.5'), 1500);
      expect(tryParseQuantityMilli('0.001'), 1);
      expect(tryParseQuantityMilli('2.25'), 2250);
      expect(tryParseQuantityMilli('-1'), isNull);
      expect(tryParseQuantityMilli('abc'), isNull);
      expect(tryParseQuantityMilli(''), isNull);
    });

    test('formatQuantityMilli', () {
      expect(formatQuantityMilli(1000), '1');
      expect(formatQuantityMilli(1500), '1.5');
      expect(formatQuantityMilli(1250), '1.25');
      expect(formatQuantityMilli(1), '0.001');
      expect(formatQuantityMilli(2000), '2');
    });
  });
}
