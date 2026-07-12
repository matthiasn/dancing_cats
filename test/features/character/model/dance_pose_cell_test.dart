import 'package:dancing_cats/features/character/model/dance_pose_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pose cells compile coherent body, limb, joint, and support tracks', () {
    const cells = [
      DancePoseCell(
        frame: 0,
        intent: 'left load',
        supportFootIds: ['foot.L'],
        body: DancePoseBody(rootDx: -10, pelvisRotation: -0.2),
        limbs: {
          'hand.R': DancePoseLimb(
            x: 80,
            y: -40,
            bendDirection: 1,
            elbowAbduction: 0.15,
          ),
        },
        joints: {'hand.R': DancePoseJoint(rotation: 0.2)},
      ),
      DancePoseCell(
        frame: 4,
        intent: 'right load',
        supportFootIds: ['foot.R'],
        body: DancePoseBody(rootDx: 10, pelvisRotation: 0.2),
        limbs: {
          'hand.R': DancePoseLimb(
            x: 100,
            y: -70,
            bendDirection: 1,
            elbowAbduction: 0.25,
            tension: 0.5,
          ),
        },
        joints: {'hand.R': DancePoseJoint(rotation: 0.4)},
      ),
    ];

    final body = bodyKeysFromPoseCells(cells);
    final hand = limbKeysFromPoseCells(cells, 'hand.R');
    final wrist = jointKeysFromPoseCells(cells, 'hand.R');
    final contacts = contactSpansFromPoseCells(cells, 8);

    expect(body.map((k) => k.rootDx), [-10, 10]);
    expect(hand.map((k) => k.elbowAbduction), [0.15, 0.25]);
    expect(hand.last.tension, 0.5);
    expect(wrist.map((k) => k.rotation), [0.2, 0.4]);
    expect(contacts, hasLength(2));
    expect(contacts.first.bone, 'foot.L');
    expect(contacts.first.start, 0);
    expect(contacts.first.end, 0.5);
    expect(contacts.last.bone, 'foot.R');
    expect(contacts.last.start, 0.5);
    expect(contacts.last.end, 1);
  });

  test('adjacent pose cells keep one continuous planted-foot anchor', () {
    const cells = [
      DancePoseCell(
        frame: 0,
        intent: 'load left',
        supportFootIds: ['foot.L'],
        body: DancePoseBody(),
      ),
      DancePoseCell(
        frame: 2,
        intent: 'move over the same plant',
        supportFootIds: ['foot.L'],
        body: DancePoseBody(),
      ),
      DancePoseCell(
        frame: 5,
        intent: 'finish over the same plant',
        supportFootIds: ['foot.L'],
        body: DancePoseBody(),
      ),
      DancePoseCell(
        frame: 8,
        intent: 'transfer right',
        supportFootIds: ['foot.R'],
        body: DancePoseBody(),
      ),
    ];

    final contacts = contactSpansFromPoseCells(cells, 16);

    expect(contacts, hasLength(2));
    expect(contacts.first.bone, 'foot.L');
    expect(contacts.first.start, 0);
    expect(contacts.first.end, 0.5);
    expect(contacts.last.bone, 'foot.R');
    expect(contacts.last.start, 0.5);
    expect(contacts.last.end, 1);
  });
}
